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

      round = game.rounds.create!(
        round_number: game.current_round,
        question: Round.generate_question,
        status: :answering,
        started_at: Time.current
      )

      # Schedule AI answers
      CollectAiAnswersJob.perform_later(round)

      round
    end
  end

  def process_voting_results!(round)
    votes = round.votes.group(:voted_for_id).count

    if votes.any?
      # Find player with most votes
      most_voted_player_id = votes.max_by { |_, count| count }.first
      most_voted_player = Player.find(most_voted_player_id)

      # Eliminate the player
      most_voted_player.update!(is_eliminated: true)

      # Check win conditions
      check_win_conditions!
    end

    round.update!(status: :completed, ended_at: Time.current)

    # Start next round if game continues
    create_next_round! unless game.completed?
  end

  private

  def create_first_round!
    game.rounds.create!(
      round_number: 1,
      question: Round.generate_question,
      status: :answering,
      started_at: Time.current
    ).tap do |round|
      CollectAiAnswersJob.perform_later(round)
    end
  end

  def check_win_conditions!
    active_players = game.active_players
    ai_count = active_players.where(is_ai: true).count
    human_count = active_players.where(is_ai: false).count

    if ai_count == 0
      # Humans win - all AIs eliminated
      game.update!(status: :completed)
    elsif human_count <= ai_count
      # AIs win - they're in majority or tied
      game.update!(status: :completed)
    elsif active_players.count <= 2
      # Game ends when only 2 players left
      game.update!(status: :completed)
    end
  end
end