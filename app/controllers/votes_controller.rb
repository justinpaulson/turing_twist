class VotesController < ApplicationController
  before_action :set_game

  def create
    @current_player = @game.players.find_by(user: Current.user)

    # Only allow voting when all rounds are complete and we're in voting phase
    if @game.all_rounds_complete? && @current_player && !@current_player.is_eliminated?
      vote = @current_player.votes_cast.build(
        game: @game,
        voted_for_id: params[:voted_for_id]
      )

      if vote.save
        # Check if voting is complete
        if @game.voting_complete?
          GameManager.new(@game).process_voting_results!
        end

        # Redirect back to voting page
        redirect_to voting_game_path(@game)
      else
        redirect_to voting_game_path(@game), alert: vote.errors.full_messages.join(", ")
      end
    else
      # If not ready for voting, redirect to game
      redirect_to @game, alert: "Cannot vote now."
    end
  end

  def results
    @current_player = @game.players.find_by(user: Current.user)
    @votes = @game.votes.includes(:voter, :voted_for)
    @vote_counts = @votes.group_by(&:voted_for).transform_values(&:count)

    # Find the eliminated player
    if @vote_counts.any?
      @eliminated_player = @vote_counts.max_by { |_, count| count }.first
    end

    @current_round = @game.current_round_object
  end

  private

  def set_game
    @game = Game.find(params[:game_id])
  end
end
