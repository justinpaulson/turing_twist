class GameManager
  attr_reader :game

  def initialize(game)
    @game = game
  end

  def start_game!
    return false unless game.can_start?

    game.transaction do
      game.update!(status: :active, current_round: 1, round_count: 0)
      create_first_round!
    end

    true
  end

  def begin_voting!
    return if game.voting_started_at

    game.update!(voting_started_at: Time.current)
    CollectVirtualVotesJob.perform_later(game) if game.active_virtual_players.exists?
  end

  def create_next_round!
    return if game.completed?

    game.transaction do
      game.increment!(:round_count)
      game.increment!(:current_round)

      # Check if we've completed all answering rounds
      if game.current_round > Game::TOTAL_ROUNDS
        # Game should be completed now
        return
      end

      round = game.rounds.create!(
        round_number: game.current_round,
        question: game.question_for_round(game.current_round),
        status: :answering,
        started_at: Time.current
      )

      # Schedule AI answers
      CollectAiAnswersJob.perform_later(round)

      round
    end
  end

  def process_voting_results!
    # Calculate scores based on votes
    calculate_scores!

    # Game is complete after voting
    game.update!(status: :completed)
  end

  private

  def create_first_round!
    game.rounds.create!(
      round_number: 1,
      question: game.question_for_round(1),
      status: :answering,
      started_at: Time.current
    ).tap do |round|
      CollectAiAnswersJob.perform_later(round)
    end
  end

  def calculate_scores!
    points_per_correct = game.points_per_correct_guess

    game.players.each do |player|
      score = 0

      # Points for correct AI guesses
      player_votes = game.votes.where(voter: player)
      player_votes.each do |vote|
        score += points_per_correct if vote.voted_for.is_ai?
      end

      # Points for deceiving others (being voted as AI when you're human)
      if !player.is_ai?
        votes_received = game.votes.where(voted_for: player).count
        score += votes_received
      end

      player.update!(score: score)
    end
  end
end
