class CollectAiVotesJob < ApplicationJob
  queue_as :default

  def perform(round)
    return unless round.voting?

    # Generate votes for all AI players
    round.game.active_ai_players.each do |ai_player|
      AiPlayerService.new(ai_player, round).generate_vote
    end

    # Check if voting is complete
    if round.voting_complete?
      GameManager.new(round.game).process_voting_results!(round)
    end
  end
end