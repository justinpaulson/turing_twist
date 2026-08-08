class CollectAiAnswersJob < ApplicationJob
  queue_as :default

  def perform(round)
    return unless round.answering?

    # Historical players replay an anonymous snapshot of real human answers.
    round.game.active_virtual_players.find_each do |virtual_player|
      VirtualPlayerService.new(virtual_player, round).submit_answer
    end

    # Generate answers for all AI players
    round.game.active_ai_players.each do |ai_player|
      AiPlayerService.new(ai_player, round).generate_answer
    end

    # Check if all players have answered
    if round.all_players_answered?
      # Move to reviewing phase so all players can see answers
      round.update!(status: :reviewing)
    end
  end
end
