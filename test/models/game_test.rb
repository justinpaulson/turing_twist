require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "can_start? returns true when player count is valid" do
    game = Game.create!(status: :waiting, current_round: 0)

    # Add 5 players (minimum)
    5.times do |i|
      user = User.create!(email_address: "player#{i}@example.com", password: "password123", password_confirmation: "password123")
      character = game.assign_next_character
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    end

    assert game.can_start?
  end

  test "can_start? returns false with too few players" do
    game = Game.create!(status: :waiting, current_round: 0)

    # Add only 4 players (below minimum of 5)
    4.times do |i|
      user = User.create!(email_address: "player#{i}@example.com", password: "password123", password_confirmation: "password123")
      character = game.assign_next_character
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    end

    assert_not game.can_start?
  end

  test "add_ai_players! creates correct number of AI players" do
    game = Game.create!(status: :waiting, current_round: 0)

    assert_difference "game.ai_players.count", Game::AI_PLAYERS_COUNT do
      game.add_ai_players!
    end

    game.ai_players.each do |ai_player|
      assert ai_player.is_ai?
      assert ai_player.ai_persona.present?
      assert ai_player.character_name.present?
      assert ai_player.character_avatar.present?
    end
  end

  test "assign_next_character returns unique characters" do
    game = Game.create!(status: :waiting, current_round: 0)

    characters = []
    5.times do
      character = game.assign_next_character
      user = User.create!(email_address: "player#{characters.count}@example.com", password: "password123", password_confirmation: "password123")
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
      characters << character
    end

    # All characters should be unique
    assert_equal characters.uniq.count, characters.count
  end

  test "private? returns true when password is set" do
    game = Game.create!(status: :waiting, current_round: 0, password: "secret123")
    assert game.private?
  end

  test "private? returns false when password is blank" do
    game = Game.create!(status: :waiting, current_round: 0, password: "")
    assert_not game.private?
  end

  test "valid_password? checks password correctly" do
    game = Game.create!(status: :waiting, current_round: 0, password: "secret123")

    assert game.valid_password?("secret123")
    assert_not game.valid_password?("wrong")
  end

  test "valid_password? returns true for public games" do
    game = Game.create!(status: :waiting, current_round: 0, password: "")

    assert game.valid_password?("anything")
    assert game.valid_password?("")
  end

  test "points_per_correct_guess scales with player count" do
    game = Game.create!(status: :waiting, current_round: 0)

    # With 6 or fewer players
    6.times do |i|
      user = User.create!(email_address: "player#{i}@example.com", password: "password123", password_confirmation: "password123")
      character = game.assign_next_character
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    end

    assert_equal 2, game.points_per_correct_guess

    # Add one more player (7 total)
    user = User.create!(email_address: "player7@example.com", password: "password123", password_confirmation: "password123")
    character = game.assign_next_character
    game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    game.reload

    assert_equal 3, game.points_per_correct_guess
  end

  test "AI personas are selected once and reused" do
    game = Game.create!(status: :waiting, current_round: 0)

    game.add_ai_players!

    # Get the persona indices
    first_indices = game.ai_persona_indices

    # Add more AI players (hypothetically)
    # The indices should remain the same
    assert_equal first_indices, game.ai_persona_indices
  end

  test "voting_complete? returns true when all players have voted twice" do
    game = Game.create!(status: :active, current_round: 6)

    # Add players
    3.times do |i|
      user = User.create!(email_address: "player#{i}@example.com", password: "password123", password_confirmation: "password123")
      character = game.assign_next_character
      game.players.create!(user: user, character_name: character[:name], character_avatar: character[:avatar])
    end

    assert_not game.voting_complete?

    # Each player votes twice
    game.active_players.each do |player|
      other_players = game.active_players.where.not(id: player.id).limit(2)
      other_players.each do |voted_for|
        player.votes_cast.create!(game: game, voted_for: voted_for)
      end
    end

    assert game.voting_complete?
  end

  test "all_rounds_complete? returns true when all rounds are completed" do
    game = Game.create!(status: :active, current_round: 5)

    # Create 5 completed rounds
    Game::TOTAL_ROUNDS.times do |i|
      game.rounds.create!(round_number: i + 1, question: "Question #{i + 1}", status: :completed)
    end

    assert game.all_rounds_complete?
  end

  test "all_rounds_complete? returns false when rounds are not completed" do
    game = Game.create!(status: :active, current_round: 3)

    # Create only 3 rounds
    3.times do |i|
      game.rounds.create!(round_number: i + 1, question: "Question #{i + 1}", status: :completed)
    end

    assert_not game.all_rounds_complete?
  end
end
