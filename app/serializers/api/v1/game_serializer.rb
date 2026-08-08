class Api::V1::GameSerializer
  def initialize(game, current_user:)
    @game = game
    @current_user = current_user
    @current_player = game.players.find_by(user: current_user)
  end

  def summary
    {
      id: game.id,
      status: game.status,
      phase: phase,
      private: game.private?,
      player_count: game.players.count,
      min_players: Game::MIN_PLAYERS,
      max_players: Game::MAX_PLAYERS,
      waiting_for: [ Game::MIN_PLAYERS - game.players.count, 0 ].max,
      current_round: game.current_round,
      total_rounds: Game::TOTAL_ROUNDS,
      is_member: current_player.present?,
      is_host: current_player&.is_host? || false,
      created_at: game.created_at
    }
  end

  def detail
    summary.merge(
      current_player_id: current_player&.id,
      invite_password: current_player&.is_host? ? game.password : nil,
      points_per_correct_guess: game.points_per_correct_guess,
      players: serialized_players,
      round: serialized_round,
      voting: serialized_voting,
      leaderboard: serialized_leaderboard
    )
  end

  private

  attr_reader :game, :current_user, :current_player

  def phase
    return "completed" if game.completed?
    return "waiting" if game.waiting?
    return "voting" if game.all_rounds_complete?

    game.current_round_object&.status || game.status
  end

  def serialized_players
    game.players.sort_by { |player| player_sort_key(player) }.map do |player|
      {
        id: player.id,
        character_name: player.character_name,
        character_avatar: player.character_avatar&.delete_suffix(".svg"),
        is_current_player: player == current_player,
        is_host: player.is_host?,
        is_ai: game.completed? ? player.is_ai? : nil,
        display_name: game.completed? && !player.is_ai? ? (player.user&.display_name || player.user&.email_address) : nil,
        score: game.completed? ? player.score : nil
      }
    end
  end

  def serialized_round
    round = game.current_round_object
    return unless round && !game.all_rounds_complete? && !game.completed?

    my_answer = round.answers.find_by(player: current_player)
    data = {
      number: round.round_number,
      status: round.status,
      question: round.question,
      answer_count: round.answers.count,
      total_players: game.active_players.count,
      my_answer: my_answer&.content
    }

    if round.reviewing? || round.completed?
      data[:answers] = round.answers.includes(:player).sort_by { |answer| player_sort_key(answer.player) }.map do |answer|
        serialize_answer(answer)
      end
    else
      data[:answers] = []
    end

    data
  end

  def serialized_voting
    return unless game.all_rounds_complete? && !game.completed?

    votes = game.votes.where(voter: current_player)
    candidates = game.active_players.includes(answers: :round).sort_by { |player| player_sort_key(player) }.map do |player|
      {
        player_id: player.id,
        character_name: player.character_name,
        character_avatar: player.character_avatar&.delete_suffix(".svg"),
        is_current_player: player == current_player,
        has_vote: votes.exists?(voted_for: player),
        answers: player.answers.sort_by { |answer| answer.round.round_number }.map { |answer| serialize_answer(answer) }
      }
    end

    expected_votes = game.active_human_players.count * Vote::MAX_VOTES_PER_PLAYER
    players_finished = game.active_human_players.count do |player|
      game.votes.where(voter: player).count >= Vote::MAX_VOTES_PER_PLAYER
    end

    {
      candidates: candidates,
      voted_for_ids: votes.pluck(:voted_for_id),
      votes_remaining: [ Vote::MAX_VOTES_PER_PLAYER - votes.count, 0 ].max,
      votes_cast: game.votes.count,
      votes_expected: expected_votes,
      players_finished: players_finished,
      human_players: game.active_human_players.count,
      started_at: game.voting_started_at
    }
  end

  def serialized_leaderboard
    return unless game.completed?

    game.players.includes(answers: :round).sort_by { |player| [ player.is_ai? ? 1 : 0, -(player.score || 0), player.id ] }.map do |player|
      votes_cast = game.votes.where(voter: player).includes(:voted_for)
      correct_votes = votes_cast.count { |vote| vote.voted_for.is_ai? }
      votes_received = game.votes.where(voted_for: player).count

      {
        player_id: player.id,
        character_name: player.character_name,
        character_avatar: player.character_avatar&.delete_suffix(".svg"),
        display_name: player.is_ai? ? "AI PLAYER" : (player.user&.display_name || player.user&.email_address),
        is_current_player: player == current_player,
        is_ai: player.is_ai?,
        score: player.score || 0,
        correct_votes: correct_votes,
        votes_received: votes_received,
        points_from_guesses: correct_votes * game.points_per_correct_guess,
        points_from_deception: player.is_ai? ? 0 : votes_received,
        answers: player.answers.sort_by { |answer| answer.round.round_number }.map { |answer| serialize_answer(answer) }
      }
    end
  end

  def serialize_answer(answer)
    {
      id: answer.id,
      player_id: answer.player_id,
      round_number: answer.round.round_number,
      question: answer.round.question,
      content: answer.content
    }
  end

  def player_sort_key(player)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      Rails.application.secret_key_base,
      "game:#{game.id}:player:#{player.id}"
    )
  end
end
