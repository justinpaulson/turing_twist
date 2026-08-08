class Api::V1::GamesController < Api::V1::BaseController
  before_action :set_game, only: [ :show, :join, :start, :skip_remaining_votes ]

  def index
    member_game_ids = current_user.players.pluck(:game_id)
    active_games = Game.includes(:players)
      .where(status: :waiting, password: [ nil, "" ])
      .where.not(id: member_game_ids)
      .order(created_at: :desc)
    my_games = Game.includes(:players)
      .where(id: member_game_ids)
      .order(Arel.sql("CASE WHEN status = 2 THEN 1 ELSE 0 END, created_at DESC"))

    render json: {
      active_games: active_games.map { |game| serialize_summary(game) },
      my_games: my_games.map { |game| serialize_summary(game) }
    }
  end

  def create
    game = Game.new(
      password: params[:password].presence,
      status: :waiting,
      current_round: 0,
      round_count: 0
    )

    game.transaction do
      game.save!
      character = game.assign_next_character
      game.players.create!(
        user: current_user,
        is_host: true,
        character_name: character[:name],
        character_avatar: character[:avatar]
      )
      game.add_ai_players!
    end

    render_game(game.reload, status: :created, message: "Game created! Waiting for more players...")
  end

  def show
    require_membership!
    return if performed?

    render_game(@game)
  end

  def join
    if @game.players.exists?(user: current_user)
      render_game(@game, message: "You're already in this game!")
    elsif @game.players.count >= Game::MAX_PLAYERS
      render_error("Game is full!", :conflict)
    elsif !@game.waiting?
      render_error("Game has already started!", :conflict)
    elsif @game.private? && !@game.valid_password?(params[:password])
      render_error("Incorrect password!", :forbidden)
    else
      character = @game.assign_next_character
      @game.players.create!(
        user: current_user,
        character_name: character[:name],
        character_avatar: character[:avatar]
      )
      render_game(@game.reload, message: "You've joined the game!")
    end
  end

  def start
    player = require_host!
    return unless player

    if @game.waiting? && @game.can_start?
      GameManager.new(@game).start_game!
      render_game(@game.reload, message: "Game started!")
    else
      render_error("Cannot start game yet.", :unprocessable_entity)
    end
  end

  def skip_remaining_votes
    player = require_host!
    return unless player

    unless @game.all_rounds_complete? && !@game.completed?
      render_error("Cannot skip votes at this time.", :unprocessable_entity)
      return
    end

    GameManager.new(@game).process_voting_results!
    render_game(@game.reload, message: "Voting complete! Remaining votes were skipped.")
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def serialize_summary(game)
    Api::V1::GameSerializer.new(game, current_user: current_user).summary
  end

  def require_membership!
    return if @game.players.exists?(user: current_user)

    render_error("Join this game before viewing it.", :forbidden)
  end

  def require_host!
    player = @game.players.find_by(user: current_user)
    return player if player&.is_host?

    render_error("Only the host can do that.", :forbidden)
    nil
  end
end
