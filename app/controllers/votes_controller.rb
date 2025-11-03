class VotesController < ApplicationController
  before_action :set_game_and_round

  def create
    @current_player = @game.players.find_by(user: Current.user)

    if @round.voting? && @current_player && !@current_player.is_eliminated?
      vote = @current_player.votes_cast.build(
        round: @round,
        voted_for_id: params[:voted_for_id]
      )

      if vote.save
        # Check if voting is complete
        if @round.voting_complete?
          GameManager.new(@game).process_voting_results!(@round)
        end

        redirect_to game_round_path(@game, @round)
      else
        redirect_to game_round_path(@game, @round), alert: vote.errors.full_messages.join(", ")
      end
    else
      redirect_to game_round_path(@game, @round), alert: "Cannot vote now."
    end
  end

  def results
    @current_player = @game.players.find_by(user: Current.user)
    @votes = @round.votes.includes(:voter, :voted_for)
    @vote_counts = @votes.group_by(&:voted_for).transform_values(&:count)

    # Find the eliminated player
    if @vote_counts.any?
      @eliminated_player = @vote_counts.max_by { |_, count| count }.first
    end

    @current_round = @game.current_round_object
  end

  private

  def set_game_and_round
    @game = Game.find(params[:game_id])
    @round = @game.rounds.find(params[:round_id])
  end
end
