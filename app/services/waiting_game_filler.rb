class WaitingGameFiller
  attr_reader :game

  def initialize(game)
    @game = game
  end

  def fill_and_start!
    return false unless eligible_for_fallback?

    historical_profiles = HistoricalCaseFinder.new(game).call
    return false unless historical_profiles&.length == seats_needed

    game.with_lock do
      game.reload
      return false unless eligible_for_fallback?

      historical_profiles.each do |historical_data|
        character = game.assign_next_character
        game.players.create!(
          is_virtual: true,
          historical_data: historical_data,
          character_name: character.fetch(:name),
          character_avatar: character.fetch(:avatar)
        )
      end

      GameManager.new(game).start_game!
    end
  end

  private

  def eligible_for_fallback?
    game.waiting? &&
      game.live_human_players.count == 1 &&
      game.virtual_players.none? &&
      game.ai_players.count == Game::AI_PLAYERS_COUNT &&
      seats_needed.positive?
  end

  def seats_needed
    Game::MIN_PLAYERS - game.players.count
  end
end
