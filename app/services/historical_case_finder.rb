class HistoricalCaseFinder
  PLACEHOLDER_ANSWERS = [ "(no response)" ].freeze

  attr_reader :game

  def initialize(game)
    @game = game
  end

  def call
    complete_player_tracks || mixed_player_tracks
  end

  private

  def complete_player_tracks
    eligible_source_games.each do |source_game|
      rounds = source_game.rounds
        .where(round_number: 1..Game::TOTAL_ROUNDS)
        .order(:round_number)
        .to_a
      next unless rounds.length == Game::TOTAL_ROUNDS

      profiles = eligible_source_players(source_game).filter_map do |player|
        build_profile(player, rounds)
      end
      return profiles.sample(seats_needed) if profiles.length >= seats_needed
    end

    nil
  end

  def mixed_player_tracks
    answers = eligible_answers
      .order(created_at: :desc)
      .limit(5_000)
      .to_a
      .shuffle

    question_pairs = answers.group_by { |answer| answer.round.question }.filter_map do |question, question_answers|
      first = question_answers.find { |answer| usable_answer?(answer) }
      next unless first

      second = question_answers.find do |answer|
        usable_answer?(answer) &&
          answer.player.user_id != first.player.user_id &&
          answer.content.strip.casecmp?(first.content.strip) == false
      end
      [ question, first, second ] if second
    end

    selected_pairs = question_pairs.sample(Game::TOTAL_ROUNDS)
    return if selected_pairs.length < Game::TOTAL_ROUNDS

    Array.new(seats_needed) do |seat_index|
      source_players = []
      archived_answers = selected_pairs.each_with_index.map do |(question, first, second), round_index|
        answer = seat_index.zero? ? first : second
        source_players << answer.player
        archived_answer(round_index + 1, question, answer.content)
      end

      {
        "display_name" => DisplayNameGenerator.generate,
        "answers" => archived_answers,
        "correct_ai_guesses" => historical_accuracy(source_players.sample)
      }
    end
  end

  def eligible_source_games
    ids = Game.completed
      .where(password: [ nil, "" ])
      .where.not(id: game.id)
      .pluck(:id)
      .shuffle

    Game.where(id: ids).index_by(&:id).then { |games| ids.filter_map { |id| games[id] } }
  end

  def eligible_source_players(source_game)
    scope = source_game.players.where(is_ai: false, is_virtual: false).where.not(user_id: nil)
    scope = scope.where.not(user_id: excluded_user_ids) if excluded_user_ids.any?
    scope.includes(:answers).to_a.shuffle
  end

  def eligible_answers
    scope = Answer
      .joins(:player, round: :game)
      .includes(:player, :round)
      .where(players: { is_ai: false, is_virtual: false })
      .where.not(players: { user_id: nil })
      .where(games: { status: Game.statuses.fetch("completed"), password: [ nil, "" ] })
      .where.not(content: [ nil, "" ])
    scope = scope.where.not(players: { user_id: excluded_user_ids }) if excluded_user_ids.any?
    scope
  end

  def build_profile(player, rounds)
    answers_by_round = player.answers.where(round: rounds).index_by(&:round_id)
    return unless rounds.all? { |round| usable_answer?(answers_by_round[round.id]) }

    {
      "display_name" => DisplayNameGenerator.generate,
      "answers" => rounds.map do |round|
        archived_answer(round.round_number, round.question, answers_by_round.fetch(round.id).content)
      end,
      "correct_ai_guesses" => historical_accuracy(player)
    }
  end

  def archived_answer(round_number, question, content)
    {
      "round_number" => round_number,
      "question" => question,
      "content" => content.strip
    }
  end

  def historical_accuracy(player)
    return 0 unless player

    player.votes_cast
      .includes(:voted_for)
      .count { |vote| vote.voted_for.is_ai? }
      .clamp(0, Vote::MAX_VOTES_PER_PLAYER)
  end

  def usable_answer?(answer)
    answer&.content.present? && !PLACEHOLDER_ANSWERS.include?(answer.content.strip.downcase)
  end

  def excluded_user_ids
    @excluded_user_ids ||= game.live_human_players.where.not(user_id: nil).pluck(:user_id)
  end

  def seats_needed
    Game::MIN_PLAYERS - game.players.count
  end
end
