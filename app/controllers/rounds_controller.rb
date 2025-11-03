class RoundsController < ApplicationController
  before_action :set_game_and_round

  def show
    @current_player = @game.players.find_by(user: Current.user)

    # Auto-redirect for completed rounds
    if @round.completed?
      if @round.round_number <= Game::TOTAL_ROUNDS
        # For answering rounds (1-5), go to next round
        next_round = @game.current_round_object
        if next_round && next_round.id != @round.id
          redirect_to game_round_path(@game, next_round) and return
        end
      else
        # For completed voting round (6), go straight to final leaderboard
        redirect_to game_path(@game) and return
      end
    end

    if @round.answering?
      @my_answer = @round.answers.find_by(player: @current_player)
      @answer_count = @round.answers.count
      @total_players = @game.active_players.count
    elsif @round.reviewing?
      @answers = @round.answers.includes(:player).shuffle
    elsif @round.voting?
      # For voting round, show ALL answers from all previous answering rounds
      # Group by player and show all their answers together
      answering_rounds = @game.rounds.where("round_number <= ?", Game::TOTAL_ROUNDS)
      all_answers = Answer.where(round: answering_rounds).includes(:player, :round).order("rounds.round_number")

      # Group answers by player
      @answers_by_player = all_answers.group_by(&:player)

      @my_votes = @game.votes.where(voter: @current_player)
      @voted_for_ids = @my_votes.pluck(:voted_for_id)
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

      # If this was the last answering round, create voting round
      if @round.round_number >= Game::TOTAL_ROUNDS
        GameManager.new(@game).create_voting_round!
        redirect_to game_round_path(@game, @game.current_round_object), notice: "All questions answered! Time to vote!"
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
