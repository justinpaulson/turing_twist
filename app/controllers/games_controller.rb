class GamesController < ApplicationController
  before_action :set_game, only: [ :show, :join, :start, :voting ]

  def index
    # Active games: waiting games that haven't started yet (joinable)
    # Only show public games (no password) in the general listing
    @active_games = Game.includes(:players).where(status: :waiting, password: [ nil, "" ]).order(created_at: :desc)

    # My games: games where the current user is a player
    # Sort by status (waiting/active first, then completed) and then by created_at
    if Current.user
      user_game_ids = Current.user.players.pluck(:game_id)
      @my_games = Game.includes(:players)
                      .where(id: user_game_ids)
                      .order(Arel.sql("CASE WHEN status = 2 THEN 1 ELSE 0 END, created_at DESC"))
    else
      @my_games = Game.none
    end
  end

  def show
    @current_player = @game.players.find_by(user: Current.user)
    @current_round = @game.current_round_object

    # If all rounds complete but game not finished, go to voting
    if @game.active? && @game.all_rounds_complete? && !@game.completed?
      redirect_to voting_game_path(@game)
      return
    end

    # Redirect to the current round if the game is active
    if @game.active? && @current_round
      redirect_to game_round_path(@game, @current_round)
      return
    end

    # Calculate detailed stats for completed games
    if @game.completed?
      calculate_player_stats
    end
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(game_params.merge(status: :waiting, current_round: 0, round_count: 0))

    if @game.save
      # Add creator as first player and host
      character = @game.assign_next_character
      @game.players.create!(
        user: Current.user,
        is_host: true,
        character_name: character[:name],
        character_avatar: character[:avatar]
      )

      # Add AI players
      @game.add_ai_players!

      redirect_to @game, notice: "Game created! Waiting for more players..."
    else
      render :new
    end
  end

  def join
    # Check if user is already in the game
    existing_player = @game.players.find_by(user: Current.user)

    if existing_player
      redirect_to @game, notice: "You're already in this game!"
    elsif @game.players.count >= Game::MAX_PLAYERS
      redirect_to games_path, alert: "Game is full!"
    elsif @game.active? || @game.completed?
      redirect_to games_path, alert: "Game has already started!"
    elsif @game.private? && !@game.valid_password?(params[:password])
      redirect_to games_path, alert: "Incorrect password!"
    else
      character = @game.assign_next_character
      @game.players.create!(
        user: Current.user,
        character_name: character[:name],
        character_avatar: character[:avatar]
      )

      # Broadcast update to all players in the waiting room
      @game.broadcast_refresh_to(@game)

      redirect_to @game, notice: "You've joined the game!"
    end
  end

  def start
    if @game.waiting? && @game.can_start?
      GameManager.new(@game).start_game!
      redirect_to @game, notice: "Game started!"
    else
      redirect_to @game, alert: "Cannot start game yet."
    end
  end

  def voting
    @current_player = @game.players.find_by(user: Current.user)

    # Redirect if not ready for voting
    unless @game.all_rounds_complete?
      redirect_to @game, alert: "Game is not ready for voting yet."
      return
    end

    # If voting is complete, redirect to final results
    if @game.voting_complete?
      redirect_to @game
      return
    end

    # Get all answers from all rounds to display
    answering_rounds = @game.rounds.where("round_number <= ?", Game::TOTAL_ROUNDS)
    all_answers = Answer.where(round: answering_rounds).includes(:player, :round).order("rounds.round_number")

    # Group answers by player
    @answers_by_player = all_answers.group_by(&:player)

    @my_votes = @game.votes.where(voter: @current_player)
    @voted_for_ids = @my_votes.pluck(:voted_for_id)
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_params
    params.require(:game).permit(:password)
  end

  def calculate_player_stats
    @player_stats = {}

    @game.players.each do |player|
      # Get votes this player received
      votes_received = @game.votes.where(voted_for: player).count

      # Get votes this player cast
      votes_cast = @game.votes.where(voter: player)

      # Count correct AI identifications
      correct_votes = votes_cast.select { |v| v.voted_for.is_ai? }.count

      # Calculate score breakdown
      points_from_correct_guesses = correct_votes * @game.points_per_correct_guess
      points_from_deception = player.is_ai? ? 0 : votes_received

      @player_stats[player.id] = {
        votes_received: votes_received,
        correct_votes: correct_votes,
        points_from_guesses: points_from_correct_guesses,
        points_from_deception: points_from_deception,
        total_score: player.score || 0
      }
    end
  end
end
