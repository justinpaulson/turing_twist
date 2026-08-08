class FillWaitingGameJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(game)
    filled = WaitingGameFiller.new(game).fill_and_start!
    Rails.logger.warn("No eligible historical case found for game #{game.id}") unless filled || !fallback_still_applicable?(game)
  end

  private

  def fallback_still_applicable?(game)
    game.reload.waiting? && game.live_human_players.count == 1
  end
end
