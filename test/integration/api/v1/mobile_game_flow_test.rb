require "test_helper"

class Api::V1::MobileGameFlowTest < ActionDispatch::IntegrationTest
  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end

  setup do
    @user = User.create!(
      email_address: "mobile@example.com",
      password: "password123",
      password_confirmation: "password123",
      display_name: "Mobile Player"
    )
    @token = issue_token(@user)
  end

  test "sign in returns a bearer token and current user" do
    post api_v1_session_url, params: {
      email_address: @user.email_address,
      password: "password123"
    }, as: :json

    assert_response :success
    assert response.parsed_body["token"].present?
    assert_equal @user.email_address, response.parsed_body.dig("user", "email_address")
    assert_not response.parsed_body["account_created"]
  end

  test "first sign in creates an account like the web app" do
    post api_v1_session_url, params: {
      email_address: "new-mobile@example.com",
      password: "password123"
    }, as: :json

    assert_response :created
    assert response.parsed_body["account_created"]
    assert_equal "new-mobile@example.com", response.parsed_body.dig("user", "email_address")
  end

  test "game endpoints require authentication" do
    get api_v1_games_url, as: :json

    assert_response :unauthorized
    assert_equal "Authentication required.", response.parsed_body["error"]
  end

  test "player can create, inspect, and list a private game" do
    post api_v1_games_url,
      params: { password: "newsprint" },
      headers: auth_headers,
      as: :json

    assert_response :created
    game_id = response.parsed_body["id"]
    assert_equal "waiting", response.parsed_body["phase"]
    assert response.parsed_body["private"]
    assert response.parsed_body["is_host"]
    assert_equal "newsprint", response.parsed_body["invite_password"]
    assert_equal 3, response.parsed_body["player_count"]
    assert response.parsed_body["players"].all? { |player| player["is_ai"].nil? }

    get api_v1_game_url(game_id), headers: auth_headers, as: :json
    assert_response :success
    assert_equal game_id, response.parsed_body["id"]

    get api_v1_games_url, headers: auth_headers, as: :json
    assert_response :success
    assert_includes response.parsed_body["my_games"].pluck("id"), game_id
  end

  test "private game rejects a wrong password and accepts the right password" do
    game = create_game_for(@user, password: "secret")
    guest = User.create!(
      email_address: "mobile-guest@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    guest_token = issue_token(guest)

    post join_api_v1_game_url(game),
      params: { password: "wrong" },
      headers: auth_headers(guest_token),
      as: :json
    assert_response :forbidden

    post join_api_v1_game_url(game),
      params: { password: "secret" },
      headers: auth_headers(guest_token),
      as: :json
    assert_response :success
    assert game.players.exists?(user: guest)
  end

  test "profile can be read and updated" do
    get api_v1_profile_url, headers: auth_headers, as: :json
    assert_response :success
    assert_equal "Mobile Player", response.parsed_body.dig("user", "display_name")

    patch api_v1_profile_url,
      params: { display_name: "News Hound" },
      headers: auth_headers,
      as: :json
    assert_response :success
    assert_equal "News Hound", response.parsed_body.dig("user", "display_name")
  end

  test "native client can submit an answer and advance a reviewed round" do
    game = create_game_for(@user)
    add_human_players(game, 2)
    game.update!(status: :active, current_round: 1)
    round = game.rounds.create!(
      round_number: 1,
      question: "Which snack wins game night?",
      status: :answering,
      started_at: Time.current
    )
    current_player = game.players.find_by!(user: @user)
    game.players.where.not(id: current_player.id).find_each do |player|
      round.answers.create!(player: player, content: "Popcorn", submitted_at: Time.current)
    end

    post answer_api_v1_game_round_url(game, 1),
      params: { content: "Pretzels" },
      headers: auth_headers,
      as: :json

    assert_response :created
    assert_equal "reviewing", response.parsed_body["phase"]
    assert_equal 5, response.parsed_body.dig("round", "answers").count

    post advance_api_v1_game_round_url(game, 1), headers: auth_headers, as: :json

    assert_response :success
    assert_equal "answering", response.parsed_body["phase"]
    assert_equal 2, response.parsed_body.dig("round", "number")
  end

  test "final vote completes the game and only then reveals AI identities" do
    game = create_game_for(@user)
    add_human_players(game, 2)
    game.update!(status: :active, current_round: 5, voting_started_at: Time.current)

    5.times do |index|
      round = game.rounds.create!(
        round_number: index + 1,
        question: "Question #{index + 1}",
        status: :completed,
        started_at: Time.current,
        ended_at: Time.current
      )
      game.players.each do |player|
        round.answers.create!(player: player, content: "Answer #{index + 1}", submitted_at: Time.current)
      end
    end

    ai_players = game.ai_players.to_a
    other_humans = game.human_players.where.not(user: @user)
    other_humans.each do |player|
      player.votes_cast.create!(game: game, voted_for: ai_players.first)
      player.votes_cast.create!(game: game, voted_for: ai_players.second)
    end

    post api_v1_game_votes_url(game),
      params: { voted_for_id: ai_players.first.id },
      headers: auth_headers,
      as: :json
    assert_response :created
    assert_equal "voting", response.parsed_body["phase"]
    assert response.parsed_body["players"].all? { |player| player["is_ai"].nil? }

    post api_v1_game_votes_url(game),
      params: { voted_for_id: ai_players.first.id },
      headers: auth_headers,
      as: :json
    assert_response :unprocessable_entity
    assert_equal "You already voted for that player.", response.parsed_body["error"]

    post api_v1_game_votes_url(game),
      params: { voted_for_id: ai_players.second.id },
      headers: auth_headers,
      as: :json
    assert_response :created
    assert_equal "completed", response.parsed_body["phase"]
    assert_equal 2, response.parsed_body["players"].count { |player| player["is_ai"] }
    assert_equal 5, response.parsed_body["leaderboard"].count
  end

  test "single player starts immediately and completes all five rounds and voting" do
    create_solo_archive
    assert_no_enqueued_jobs(only: FillWaitingGameJob) do
      post api_v1_games_url, params: { mode: "solo" }, headers: auth_headers, as: :json
    end
    assert_response :created
    game = Game.find(response.parsed_body.fetch("id"))
    assert_equal "solo", response.parsed_body["mode"]
    assert_equal "answering", response.parsed_body["phase"]
    assert_equal 1, game.live_human_players.count
    assert_equal 2, game.virtual_players.count
    assert response.parsed_body["players"].all? { |player| player["is_ai"].nil? }

    guest = User.create!(email_address: "solo-outsider@example.com", password: "password123")
    post join_api_v1_game_url(game), headers: auth_headers(issue_token(guest)), as: :json
    assert_response :conflict
    get api_v1_game_url(game), headers: auth_headers(issue_token(guest)), as: :json
    assert_response :forbidden

    Game::TOTAL_ROUNDS.times do |index|
      round = game.reload.current_round_object
      assert_equal "Solo question #{index + 1}?", round.question
      game.virtual_players.each { |player| VirtualPlayerService.new(player, round).submit_answer }
      # Deterministic AI answers keep this integration test independent of the LLM provider.
      game.ai_players.each do |player|
        round.answers.create!(player: player, content: "AI answer #{index}", submitted_at: Time.current)
      end
      post answer_api_v1_game_round_url(game, index + 1),
        params: { content: "My answer #{index}" }, headers: auth_headers, as: :json
      assert_response :created
      assert_equal "reviewing", response.parsed_body["phase"]
      assert_equal 5, response.parsed_body.dig("round", "answers").length
      assert response.parsed_body["players"].all? { |player| player["is_ai"].nil? }
      post advance_api_v1_game_round_url(game, index + 1), headers: auth_headers, as: :json
      assert_response :success
    end
    assert_equal "voting", response.parsed_body["phase"]
    CollectVirtualVotesJob.perform_now(game.reload)
    game.ai_players.each do |player|
      post api_v1_game_votes_url(game), params: { voted_for_id: player.id }, headers: auth_headers, as: :json
      assert_response :created
    end
    assert_equal "completed", response.parsed_body["phase"]
    assert_equal 2, response.parsed_body["players"].count { |player| player["is_ai"] }
    me = response.parsed_body["leaderboard"].find { |entry| entry["is_current_player"] }
    assert_equal 4, me["points_from_guesses"]
    get api_v1_games_url, headers: auth_headers, as: :json
    assert_equal "solo", response.parsed_body["my_games"].find { |entry| entry["id"] == game.id }["mode"]
  end

  test "unavailable solo cases roll back without leaving a lobby or jobs" do
    assert_no_difference [ "Game.count", "Player.count", "Round.count" ] do
      assert_no_enqueued_jobs do
        post api_v1_games_url, params: { mode: "solo" }, headers: auth_headers, as: :json
      end
    end
    assert_response :unprocessable_entity
    assert_match "No single-player case", response.parsed_body["error"]
  end

  test "private archives and the requesting player's own answers cannot seed solo play" do
    archive = create_solo_archive
    archive.update!(password: "private")
    post api_v1_games_url, params: { mode: "solo" }, headers: auth_headers, as: :json
    assert_response :unprocessable_entity
    archive.update!(password: nil)
    archive.live_human_players.first.update!(user: @user)
    post api_v1_games_url, params: { mode: "solo" }, headers: auth_headers, as: :json
    assert_response :unprocessable_entity
  end

  test "unknown game modes are rejected without creating a game" do
    assert_no_difference "Game.count" do
      post api_v1_games_url, params: { mode: "unknown" }, headers: auth_headers, as: :json
    end
    assert_response :unprocessable_entity
  end

  private

  def create_solo_archive
    game = Game.create!(status: :completed, current_round: 5, round_count: 5)
    add_human_players(game, 2)
    5.times do |index|
      round = game.rounds.create!(round_number: index + 1, question: "Solo question #{index + 1}?", status: :completed)
      game.players.each do |player|
        round.answers.create!(player: player, content: "Archived answer #{player.id} #{index}", submitted_at: Time.current)
      end
    end
    game
  end

  def issue_token(user)
    _, token = Session.create_with_api_token!(
      user: user,
      user_agent: "Rails test",
      ip_address: "127.0.0.1"
    )
    token
  end

  def auth_headers(token = @token)
    { "Authorization" => "Bearer #{token}" }
  end

  def create_game_for(user, password: nil)
    game = Game.create!(status: :waiting, current_round: 0, round_count: 0, password: password)
    character = game.assign_next_character
    game.players.create!(
      user: user,
      is_host: true,
      character_name: character[:name],
      character_avatar: character[:avatar]
    )
    game.add_ai_players!
    game
  end

  def add_human_players(game, count)
    count.times do |index|
      user = User.create!(
        email_address: "mobile-player-#{game.id}-#{index}@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
      character = game.assign_next_character
      game.players.create!(
        user: user,
        character_name: character[:name],
        character_avatar: character[:avatar]
      )
    end
  end
end
