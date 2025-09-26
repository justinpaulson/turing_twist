class GamesController < ApplicationController
  before_action :set_game, only: [:show, :join, :start]

  def index
    @games = Game.includes(:players).all
    @current_player = Current.user.players.joins(:game).find_by(games: { status: [:waiting, :active] })
  end

  def show
    @current_player = @game.players.find_by(user: Current.user)
    @current_round = @game.current_round_object

    # Redirect to the current round if the game is active
    if @game.active? && @current_round
      redirect_to game_round_path(@game, @current_round)
      return
    end

    # Otherwise show game status
    if @current_round&.voting?
      @answers = @current_round.answers.includes(:player)
      @my_vote = @current_round.votes.find_by(voter: @current_player)
    elsif @current_round&.answering?
      @my_answer = @current_round.answers.find_by(player: @current_player)
    end
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(status: :waiting, current_round: 0, round_count: 0)

    if @game.save
      # Add creator as first player
      @game.players.create!(user: Current.user)

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
    else
      @game.players.create!(user: Current.user)

      # Auto-start if we have enough players
      if @game.players.count >= Game::MIN_PLAYERS
        GameManager.new(@game).start_game!
      end

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

  private

  def set_game
    @game = Game.find(params[:id])
  end
end