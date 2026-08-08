class CollectVirtualVotesJob < ApplicationJob
  queue_as :default

  def perform(game)
    return unless game.active? && game.all_rounds_complete?

    game.active_virtual_players.find_each do |player|
      cast_historical_ballot(player, game)
    end

    game.reload
    GameManager.new(game).process_voting_results! if game.voting_complete? && !game.completed?
  end

  private

  def cast_historical_ballot(player, game)
    player.with_lock do
      existing_votes = player.votes_cast.where(game: game).includes(:voted_for).to_a
      votes_remaining = Vote::MAX_VOTES_PER_PLAYER - existing_votes.length
      return unless votes_remaining.positive?

      existing_correct = existing_votes.count { |vote| vote.voted_for.is_ai? }
      correct_remaining = [ player.historical_correct_ai_guesses - existing_correct, votes_remaining ].min

      selected_ids = existing_votes.map(&:voted_for_id)
      correct_candidates = game.active_ai_players.where.not(id: selected_ids).to_a.sample(correct_remaining)
      wrong_remaining = votes_remaining - correct_candidates.length
      wrong_candidates = game.active_human_players
        .where.not(id: selected_ids + [ player.id ])
        .to_a
        .sample(wrong_remaining)

      (correct_candidates + wrong_candidates).each do |candidate|
        player.votes_cast.create!(game: game, voted_for: candidate)
      end
    end
  end
end
