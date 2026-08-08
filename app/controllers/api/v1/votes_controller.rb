class Api::V1::VotesController < Api::V1::BaseController
  before_action :set_game

  def create
    current_player = @game.players.find_by(user: current_user)
    unless @game.all_rounds_complete? && current_player && !current_player.is_eliminated?
      render_error("Cannot vote now.", :unprocessable_entity)
      return
    end
    if @game.completed? || @game.voting_complete?
      render_error("Voting has ended.", :conflict)
      return
    end

    candidate = @game.active_players.find(params.require(:voted_for_id))
    if current_player.votes_cast.exists?(game: @game, voted_for: candidate)
      render_error("You already voted for that player.", :unprocessable_entity)
      return
    end

    vote = current_player.votes_cast.build(
      game: @game,
      voted_for: candidate
    )

    if vote.save
      GameManager.new(@game).process_voting_results! if @game.voting_complete?
      render_game(@game.reload, status: :created, message: "Vote recorded.")
    else
      render_error(vote.errors.full_messages.to_sentence, :unprocessable_entity)
    end
  end

  private

  def set_game
    @game = Game.find(params[:game_id])
  end
end
