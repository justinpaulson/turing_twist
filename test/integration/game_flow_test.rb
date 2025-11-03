require "test_helper"

class GameFlowTest < ActionDispatch::IntegrationTest
  test "complete game flow from creation to completion" do
    # Create a user and sign in
    user = User.create!(
      email_address: "player1@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post session_url, params: { email_address: user.email_address, password: "password123" }
    assert_response :redirect

    # Create a new game
    assert_difference "Game.count", 1 do
      post games_url, params: { game: { password: "" } }
    end

    game = Game.last
    assert_equal "waiting", game.status
    assert_equal 1, game.human_players.count
    assert_equal 2, game.ai_players.count
    assert game.players.find_by(user: user).is_host?

    # Add more human players to reach minimum
    4.times do |i|
      other_user = User.create!(
        email_address: "player#{i + 2}@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      delete session_url
      post session_url, params: { email_address: other_user.email_address, password: "password123" }
      post join_game_url(game)
      game.reload
    end

    assert_equal 5, game.human_players.count
    assert game.can_start?

    # Start the game
    post start_game_url(game)
    game.reload

    assert_equal "active", game.status
    assert_equal 1, game.current_round
    assert_equal 1, game.rounds.count

    first_round = game.current_round_object
    assert_equal "answering", first_round.status
    assert first_round.question.present?
  end

  test "player can submit answer during answering phase" do
    game = create_game_with_players(player_count: 5)
    game.update!(status: :active, current_round: 1)
    round = game.rounds.create!(
      round_number: 1,
      question: "What is your favorite color?",
      status: :answering,
      started_at: Time.current
    )

    player = game.human_players.first
    user = player.user

    # Sign in as this player
    post session_url, params: { email_address: user.email_address, password: "password123" }

    # Submit an answer
    assert_difference "Answer.count", 1 do
      post submit_answer_game_round_url(game, round.round_number),
        params: { content: "Blue because it's calming" }
    end

    answer = Answer.last
    assert_equal player, answer.player
    assert_equal "Blue because it's calming", answer.content
    assert answer.submitted_at.present?
  end

  test "round transitions to reviewing when all players answer" do
    game = create_game_with_players(player_count: 5)
    game.update!(status: :active, current_round: 1)
    round = game.rounds.create!(
      round_number: 1,
      question: "What is your favorite color?",
      status: :answering,
      started_at: Time.current
    )

    # All human players submit answers
    game.human_players.each do |player|
      player.answers.create!(
        round: round,
        content: "My answer",
        submitted_at: Time.current
      )
    end

    # AI players submit answers
    game.ai_players.each do |player|
      player.answers.create!(
        round: round,
        content: "AI answer",
        submitted_at: Time.current
      )
    end

    round.reload
    assert round.all_players_answered?

    # Transition to reviewing
    round.update!(status: :reviewing)
    assert_equal "reviewing", round.status
  end

  test "voting round allows players to vote for AI suspects" do
    game = create_game_with_players(player_count: 5)
    game.update!(status: :active, current_round: 6)

    voting_round = game.rounds.create!(
      round_number: 6,
      question: "Vote for the 2 players you think are AI",
      status: :voting,
      started_at: Time.current
    )

    player = game.human_players.first
    ai_player = game.ai_players.first

    # Submit a vote
    assert_difference "Vote.count", 1 do
      player.votes_cast.create!(
        game: game,
        voted_for: ai_player
      )
    end

    vote = Vote.last
    assert_equal player, vote.voter
    assert_equal ai_player, vote.voted_for
  end

  test "cannot vote for yourself" do
    game = create_game_with_players(player_count: 5)
    voting_round = game.rounds.create!(
      round_number: 6,
      question: "Vote for the 2 players you think are AI",
      status: :voting
    )

    player = game.human_players.first

    vote = player.votes_cast.build(
      game: game,
      voted_for: player
    )

    assert_not vote.valid?
    assert_includes vote.errors[:voted_for], "cannot vote for yourself"
  end

  test "cannot vote for more than 2 players" do
    game = create_game_with_players(player_count: 5)
    voting_round = game.rounds.create!(
      round_number: 6,
      question: "Vote for the 2 players you think are AI",
      status: :voting
    )

    player = game.human_players.first
    other_players = game.active_players.where.not(id: player.id).limit(3)

    # Create 2 votes (should succeed)
    player.votes_cast.create!(game: game, voted_for: other_players[0])
    player.votes_cast.create!(game: game, voted_for: other_players[1])

    # Try to create a 3rd vote (should fail)
    vote = player.votes_cast.build(
      game: game,
      voted_for: other_players[2]
    )

    assert_not vote.valid?
    assert_includes vote.errors[:base], "cannot vote for more than 2 players"
  end

  test "game calculates scores correctly after voting" do
    game = create_game_with_players(player_count: 5)
    voting_round = game.rounds.create!(
      round_number: 6,
      question: "Vote for the 2 players you think are AI",
      status: :voting
    )

    human_player = game.human_players.first
    ai_player1 = game.ai_players.first
    ai_player2 = game.ai_players.second

    # Human player correctly identifies both AIs
    human_player.votes_cast.create!(game: game, voted_for: ai_player1)
    human_player.votes_cast.create!(game: game, voted_for: ai_player2)

    # Process voting results
    GameManager.new(game).process_voting_results!

    human_player.reload
    points_per_correct = game.points_per_correct_guess

    # Should get points for 2 correct AI identifications
    assert_equal points_per_correct * 2, human_player.score
  end

  test "human player gets deception points when voted as AI" do
    game = create_game_with_players(player_count: 5)
    voting_round = game.rounds.create!(
      round_number: 6,
      question: "Vote for the 2 players you think are AI",
      status: :voting
    )

    human_player1 = game.human_players.first
    human_player2 = game.human_players.second
    other_player = game.human_players.third

    # Two players vote for human_player1 thinking they're AI
    human_player2.votes_cast.create!(game: game, voted_for: human_player1)
    other_player.votes_cast.create!(game: game, voted_for: human_player1)

    # Process voting results
    GameManager.new(game).process_voting_results!

    human_player1.reload
    # Should get 2 deception points (one per vote received)
    assert_equal 2, human_player1.score
  end

  test "private game requires password to join" do
    user1 = User.create!(
      email_address: "host@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post session_url, params: { email_address: user1.email_address, password: "password123" }

    # Create private game
    post games_url, params: { game: { password: "secret123" } }
    game = Game.last

    assert game.private?
    assert_equal "secret123", game.password

    # Another user tries to join without password
    user2 = User.create!(
      email_address: "player2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    delete session_url
    post session_url, params: { email_address: user2.email_address, password: "password123" }

    # Try to join without password
    post join_game_url(game)
    assert_redirected_to games_path
    assert_equal "Incorrect password!", flash[:alert]

    # Join with correct password
    post join_game_url(game), params: { password: "secret123" }
    assert_redirected_to game_path(game)
    assert game.players.exists?(user: user2)
  end

  private

  def create_game_with_players(player_count:)
    game = Game.create!(status: :waiting, current_round: 0, round_count: 0)

    # Create human players
    player_count.times do |i|
      user = User.create!(
        email_address: "player#{i + 1}@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      character = game.assign_next_character
      game.players.create!(
        user: user,
        is_host: i.zero?,
        character_name: character[:name],
        character_avatar: character[:avatar]
      )
    end

    # Create AI players
    game.add_ai_players!

    game
  end
end
