class RoundsController < ApplicationController
  before_action :set_game_and_round

  def show
    @current_player = @game.players.find_by(user: Current.user)

    # Redirect old voting rounds (round 6+) to the voting page
    if @round.round_number > Game::TOTAL_ROUNDS
      redirect_to voting_game_path(@game) and return
    end

    # Auto-redirect for completed rounds
    if @round.completed?
      # If this was the last answering round (round 5), go to voting
      if @round.round_number >= Game::TOTAL_ROUNDS
        redirect_to voting_game_path(@game) and return
      end

      # For earlier answering rounds (1-4), go to next round
      next_round = @game.current_round_object
      if next_round && next_round.id != @round.id
        redirect_to game_round_path(@game, next_round) and return
      end
    end

    if @round.answering?
      @my_answer = @round.answers.find_by(player: @current_player)
      @answer_count = @round.answers.count
      @total_players = @game.active_players.count
    elsif @round.reviewing?
      @answers = @round.answers.includes(:player).shuffle
    elsif @round.completed?
      @answers = @round.answers.includes(:player)
      @votes = @game.votes.includes(:voter, :voted_for)
      @vote_counts = @votes.group(:voted_for).count
    end
  end

  def submit_answer
    @current_player = @game.players.find_by(user: Current.user)

    if @round.answering? && @current_player && !@current_player.is_eliminated?
      answer = @current_player.answers.build(
        round: @round,
        content: params[:content],
        submitted_at: Time.current
      )

      if answer.save
        # Check if all players have answered
        if @round.all_players_answered?
          @round.update!(status: :reviewing)
          redirect_to game_round_path(@game, @round)
        else
          redirect_to game_round_path(@game, @round)
        end
      else
        redirect_to game_round_path(@game, @round), alert: answer.errors.full_messages.join(", ")
      end
    else
      redirect_to game_round_path(@game, @round), alert: "Cannot submit answer now."
    end
  end

  def start_voting
    if @round.reviewing?
      # Mark this round as completed
      @round.update!(status: :completed, ended_at: Time.current)

      # If this was the last answering round, go to voting page
      if @round.round_number >= Game::TOTAL_ROUNDS
        redirect_to voting_game_path(@game), notice: "All questions answered! Time to vote!"
      else
        # Create next answering round
        GameManager.new(@game).create_next_round!
        redirect_to game_round_path(@game, @game.current_round_object)
      end
    else
      redirect_to game_round_path(@game, @round), alert: "Not ready to start voting."
    end
  end

  private

  def set_game_and_round
    @game = Game.find(params[:game_id])
    @round = @game.rounds.find_by!(round_number: params[:round_number])
  end
end
