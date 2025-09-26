class RoundsController < ApplicationController
  before_action :set_game_and_round

  def show
    @current_player = @game.players.find_by(user: Current.user)

    if @round.voting?
      @answers = @round.answers.includes(:player).shuffle
      @my_vote = @round.votes.find_by(voter: @current_player)
    elsif @round.answering?
      @my_answer = @round.answers.find_by(player: @current_player)
    elsif @round.completed?
      @answers = @round.answers.includes(:player)
      @votes = @round.votes.includes(:voter, :voted_for)
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
          @round.update!(status: :voting)
          CollectAiVotesJob.perform_later(@round)
        end

        redirect_to game_round_path(@game, @round)
      else
        redirect_to game_round_path(@game, @round), alert: answer.errors.full_messages.join(", ")
      end
    else
      redirect_to game_round_path(@game, @round), alert: "Cannot submit answer now."
    end
  end

  private

  def set_game_and_round
    @game = Game.find(params[:game_id])
    @round = @game.rounds.find(params[:id])
  end
end
