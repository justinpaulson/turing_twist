class CollectAiVotesJob < ApplicationJob
  queue_as :default

  def perform(game)
    return unless game.all_rounds_complete?

    # Generate votes for all AI players
    game.active_ai_players.each do |ai_player|
      AiPlayerService.new(ai_player, game).generate_vote
    end

    # Check if voting is complete
    if game.voting_complete?
      GameManager.new(game).process_voting_results!
    end
  end
end
