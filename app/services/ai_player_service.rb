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
    response = chat.complete

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
    [
      {
        role: "system",
        content: "#{player.ai_persona}\n\nIMPORTANT: Keep your answer EXTREMELY SHORT - often just a few words or a single short sentence. Most answers should be 5-10 words MAX. Real people don't write paragraphs in quick chat games. Just answer the question directly and briefly. Be specific (mention real song names, brands, places, etc). The shorter, the better. NEVER use emojis in your response - real people almost never use them in this game."
      },
      {
        role: "user",
        content: round.question
      }
    ]
  end
end
