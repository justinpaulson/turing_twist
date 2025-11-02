require "test_helper"

class RoundTest < ActiveSupport::TestCase
  test "generate_question returns random question" do
    game = Game.create!(status: :waiting, current_round: 0)

    question = Round.generate_question(game)

    assert question.present?
    assert Round::QUESTIONS.include?(question)
  end

  test "generate_question avoids previously used questions" do
    game = Game.create!(status: :active, current_round: 1)

    # Create rounds with all but one question
    used_questions = Round::QUESTIONS[0...-1]
    used_questions.each_with_index do |question, i|
      game.rounds.create!(round_number: i + 1, question: question, status: :completed)
    end

    # Next question should be the unused one
    next_question = Round.generate_question(game)
    assert_equal Round::QUESTIONS.last, next_question
  end

  test "all_players_answered? returns true when all active players have answered" do
    game = Game.create!(status: :active, current_round: 1)

    # Add players
    3.times do |i|
      user = User.create!(email_address: "player#{i}@example.com", password: "password123", password_confirmation: "password123")
      character = game.assign_next_character
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    end

    round = game.rounds.create!(round_number: 1, question: "Test?", status: :answering)

    assert_not round.all_players_answered?

    # All players answer
    game.active_players.each do |player|
      player.answers.create!(round: round, content: "Answer", submitted_at: Time.current)
    end

    assert round.all_players_answered?
  end

  test "voting_complete? returns true when all players have voted twice" do
    game = Game.create!(status: :active, current_round: 6)

    # Add players
    3.times do |i|
      user = User.create!(email_address: "player#{i}@example.com", password: "password123", password_confirmation: "password123")
      character = game.assign_next_character
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    end

    round = game.rounds.create!(round_number: 6, question: "Vote", status: :voting)

    assert_not round.voting_complete?

    # Each player votes twice
    game.active_players.each do |player|
      other_players = game.active_players.where.not(id: player.id).limit(2)
      other_players.each do |voted_for|
        player.votes_cast.create!(round: round, voted_for: voted_for)
      end
    end

    assert round.voting_complete?
  end

  test "to_param returns round_number as string" do
    game = Game.create!(status: :active, current_round: 1)
    round = game.rounds.create!(round_number: 3, question: "Test?", status: :answering)

    assert_equal "3", round.to_param
  end
end
