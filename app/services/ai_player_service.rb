class AiPlayerService
  attr_reader :player, :round

  def initialize(player, round)
    @player = player
    @round = round
  end

  def generate_answer
    return if player.answers.exists?(round: round)

    prompt = build_answer_prompt

    # Build chat with messages
    chat = RubyLLM.chat
    prompt.each { |msg| chat.add_message(role: msg[:role], content: msg[:content]) }
    response = chat.complete

    player.answers.create!(
      round: round,
      content: response.content,
      submitted_at: Time.current
    )
  end

  def generate_vote
    # Check if this AI has already cast all their votes
    existing_votes_count = player.votes_cast.where(round: round).count
    return if existing_votes_count >= Vote::MAX_VOTES_PER_PLAYER

    # Get all answers from answering rounds (1-5)
    answering_rounds = round.game.rounds.where("round_number <= ?", Game::TOTAL_ROUNDS)
    all_answers = Answer.where(round: answering_rounds).includes(:player, :round)

    # Get answers grouped by player, excluding this AI and already voted players
    already_voted_ids = player.votes_cast.where(round: round).pluck(:voted_for_id)
    available_players = round.game.active_players.where.not(id: [ player.id ] + already_voted_ids)

    return if available_players.empty?

    # Build context with all answers for each available player
    prompt = build_voting_prompt_with_all_answers(all_answers, available_players, already_voted_ids)
    chat = RubyLLM.chat
    prompt.each { |msg| chat.add_message(role: msg[:role], content: msg[:content]) }
    response = chat.complete

    # Parse response to get player ID
    voted_player_id = parse_vote_response_from_players(response, available_players)

    player.votes_cast.create!(
      round: round,
      voted_for_id: voted_player_id
    )

    # If we haven't voted twice yet, vote again
    if existing_votes_count + 1 < Vote::MAX_VOTES_PER_PLAYER
      generate_vote
    end
  end

  private

  def build_answer_prompt
    [
      {
        role: "system",
        content: "#{player.ai_persona}\n\nIMPORTANT: Keep your answer EXTREMELY SHORT - often just a few words or a single short sentence. Most answers should be 5-10 words MAX. Real people don't write paragraphs in quick chat games. Just answer the question directly and briefly. Be specific (mention real song names, brands, places, etc). The shorter, the better."
      },
      {
        role: "user",
        content: round.question
      }
    ]
  end

  def build_voting_prompt_with_all_answers(all_answers, available_players, already_voted_ids)
    # Group answers by player
    answers_by_player = all_answers.group_by(&:player)

    players_text = available_players.map.with_index do |player, idx|
      player_answers = answers_by_player[player] || []
      answers_text = player_answers.map { |a| "Q: #{a.round.question}\nA: #{a.content}" }.join("\n")
      "#{idx + 1}. Player #{player.character_name}:\n#{answers_text}"
    end.join("\n\n")

    already_voted_text = if already_voted_ids.any?
      already_voted_names = round.game.players.where(id: already_voted_ids).pluck(:character_name).join(", ")
      "\n\nYou have already voted for: #{already_voted_names}. Choose someone different."
    else
      ""
    end

    [
      {
        role: "system",
        content: "You are playing Turing Twist, a game where you need to identify which players are AI. You need to vote for 2 different players total. Review each player's answers across all 5 rounds and identify who seems most likely to be an AI based on their writing style, patterns, or artificial-sounding responses. Respond with just the number of the player you want to vote for."
      },
      {
        role: "user",
        content: "Review these players' complete answer history:#{already_voted_text}\n\n#{players_text}\n\nWhich player seems most like an AI? (respond with just the number)"
      }
    ]
  end

  def parse_vote_response_from_players(response, available_players)
    # Extract number from response
    content = response.is_a?(String) ? response : response.content
    number = content.strip.gsub(/\D/, "").to_i

    # Default to random player if parsing fails
    return available_players.sample.id if number < 1 || number > available_players.count

    # Get the player ID for the selected player
    available_players[number - 1].id
  end
end
