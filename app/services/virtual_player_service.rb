class VirtualPlayerService
  attr_reader :player, :round

  def initialize(player, round)
    @player = player
    @round = round
  end

  def submit_answer
    return if player.answers.exists?(round: round)

    archived_answer = player.historical_answer_for(round.round_number)
    raise KeyError, "Missing historical answer for round #{round.round_number}" unless archived_answer
    raise ArgumentError, "Historical question does not match the current round" unless archived_answer.fetch("question") == round.question

    player.answers.create!(
      round: round,
      content: archived_answer.fetch("content"),
      submitted_at: Time.current
    )
  end
end
