class AiPlayerService
  attr_reader :player, :round, :game

  def initialize(player, round_or_game)
    @player = player
    if round_or_game.is_a?(Round)
      @round = round_or_game
      @game = round_or_game.game
    else
      @game = round_or_game
      @round = nil
    end
  end

  def generate_answer
    return if player.answers.exists?(round: round)

    prompt = build_answer_prompt

    # Build chat with messages
    chat = RubyLLM.chat
    prompt.each { |msg| chat.add_message(role: msg[:role], content: msg[:content]) }
    # Use higher temperature for more diverse, creative answers
    response = chat.with_temperature(1.2).complete

    player.answers.create!(
      round: round,
      content: response.content,
      submitted_at: Time.current
    )
  end

  # AI voting has been removed - AIs do not vote
  # Only human players vote

  private

  def build_answer_prompt
    # Get existing AI answers for this round to ensure diversity
    existing_ai_answers = round.answers
                               .joins(:player)
                               .where(players: { is_ai: true })
                               .where.not(player_id: player.id)
                               .pluck(:content)

    base_instructions = "#{player.ai_persona}\n\nIMPORTANT: Keep your answer EXTREMELY SHORT - often just a few words or a single short sentence. Most answers should be 5-10 words MAX. Real people don't write paragraphs in quick chat games. Just answer the question directly and briefly. Be specific (mention real song names, brands, places, etc). The shorter, the better. NEVER use emojis in your response - real people almost never use them in this game.\n\nCRITICAL: You are playing a game where humans are trying to identify which players are AI. Your goal is to sound completely human and natural. NEVER mention being an AI, bot, code, algorithm, or any reference to being non-human. NEVER say things like 'I am only code' or 'as an AI' or make jokes about being a computer. Act like a real person with real opinions and experiences."

    # Add diversity instructions if other AI answers exist
    if existing_ai_answers.any?
      diversity_note = "\n\nOTHER ANSWERS ALREADY SUBMITTED:\n#{existing_ai_answers.map { |a| "- #{a}" }.join("\n")}\n\nYou MUST provide a DIFFERENT answer. Do not repeat or closely paraphrase the answers above. Think of a completely different response to the question."
      base_instructions += diversity_note
    end

    [
      {
        role: "system",
        content: base_instructions
      },
      {
        role: "user",
        content: round.question
      }
    ]
  end
end
