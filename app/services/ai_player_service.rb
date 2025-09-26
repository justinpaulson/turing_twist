class AiPlayerService
  attr_reader :player, :round

  def initialize(player, round)
    @player = player
    @round = round
  end

  def generate_answer
    return if player.answers.exists?(round: round)

    prompt = build_answer_prompt
    response = RubyLLM.chat(prompt)

    player.answers.create!(
      round: round,
      content: response,
      submitted_at: Time.current
    )
  end

  def generate_vote
    return if player.votes_cast.exists?(round: round)

    # Get all answers except the AI's own
    other_answers = round.answers.where.not(player: player)
    return if other_answers.empty?

    prompt = build_voting_prompt(other_answers)
    response = RubyLLM.chat(prompt)

    # Parse response to get player ID
    voted_player_id = parse_vote_response(response, other_answers)

    player.votes_cast.create!(
      round: round,
      voted_for_id: voted_player_id
    )
  end

  private

  def build_answer_prompt
    [
      {
        role: "system",
        content: "#{player.ai_persona} You are playing a game where humans try to identify AI players. Answer the following question naturally and authentically, as a human would. Keep your response to 2-3 sentences."
      },
      {
        role: "user",
        content: round.question
      }
    ]
  end

  def build_voting_prompt(other_answers)
    answers_text = other_answers.map.with_index do |answer, idx|
      "#{idx + 1}. #{answer.content}"
    end.join("\n")

    [
      {
        role: "system",
        content: "You are playing a game where you need to identify which player is most likely an AI. Read the following answers to the question '#{round.question}' and choose which one seems most artificial or least human-like. Respond with just the number."
      },
      {
        role: "user",
        content: "Answers:\n#{answers_text}\n\nWhich answer seems most like it was written by an AI? (respond with just the number)"
      }
    ]
  end

  def parse_vote_response(response, other_answers)
    # Extract number from response
    number = response.strip.gsub(/\D/, '').to_i

    # Default to first answer if parsing fails
    return other_answers.first.player_id if number < 1 || number > other_answers.count

    # Get the player ID for the selected answer
    other_answers[number - 1].player_id
  end
end