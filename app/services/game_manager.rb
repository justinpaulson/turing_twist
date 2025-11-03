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
        question: Round.generate_question(game),
        status: :answering,
        started_at: Time.current
      )

      # Schedule AI answers
      CollectAiAnswersJob.perform_later(round)

      round
    end
  end

  def create_voting_round!
    # Create a final voting round after all 5 answering rounds
    game.transaction do
      game.increment!(:round_count)
      game.increment!(:current_round)

      round = game.rounds.create!(
        round_number: Game::TOTAL_ROUNDS + 1,
        question: "Vote for the 2 players you think are AI",
        status: :voting,
        started_at: Time.current
      )

      # Generate AI votes immediately (inline) to ensure they happen
      # even if background jobs aren't running
      game.active_ai_players.each do |ai_player|
        AiPlayerService.new(ai_player, round).generate_vote
      end

      round
    end
  end

  def process_voting_results!(round)
    # Calculate scores based on votes
    calculate_scores!(round)

    round.update!(status: :completed, ended_at: Time.current)

    # Game is complete after voting
    game.update!(status: :completed)
  end

  private

  def create_first_round!
    game.rounds.create!(
      round_number: 1,
      question: Round.generate_question(game),
      status: :answering,
      started_at: Time.current
    ).tap do |round|
      CollectAiAnswersJob.perform_later(round)
    end
  end

  def calculate_scores!(round)
    points_per_correct = game.points_per_correct_guess

    game.players.each do |player|
      score = 0

      # Points for correct AI guesses
      player_votes = round.votes.where(voter: player)
      player_votes.each do |vote|
        score += points_per_correct if vote.voted_for.is_ai?
      end

      # Points for deceiving others (being voted as AI when you're human)
      if !player.is_ai?
        votes_received = round.votes.where(voted_for: player).count
        score += votes_received
      end

      player.update!(score: score)
    end
  end
end
