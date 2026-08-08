require "test_helper"

class SoloCaseTest < ActiveSupport::TestCase
  setup do
    @source_game, @source_players = create_historical_game
    @waiting_game, @host = create_waiting_game
  end

  test "fills a one-human lobby with anonymous historical players and starts it" do
    assert_difference -> { Player.where(is_virtual: true).count }, 2 do
      assert WaitingGameFiller.new(@waiting_game).fill_and_start!
    end

    @waiting_game.reload
    assert @waiting_game.active?
    assert_equal Game::MIN_PLAYERS, @waiting_game.players.count
    assert_equal 1, @waiting_game.live_human_players.count
    assert_equal 2, @waiting_game.virtual_players.count
    assert_equal "Archived question 1?", @waiting_game.current_round_object.question

    archived_content = @waiting_game.virtual_players.map do |player|
      assert player.user.nil?
      assert player.public_display_name.present?
      player.historical_answer_for(1).fetch("content")
    end
    assert_equal [ "Human 1 answer 1", "Human 2 answer 1" ], archived_content.sort
  end

  test "replays historical answers and questions throughout the game" do
    WaitingGameFiller.new(@waiting_game).fill_and_start!
    first_round = @waiting_game.current_round_object

    @waiting_game.virtual_players.each do |player|
      VirtualPlayerService.new(player, first_round).submit_answer
    end

    assert_equal [ "Human 1 answer 1", "Human 2 answer 1" ], first_round.answers.pluck(:content).sort

    first_round.update!(status: :completed)
    second_round = GameManager.new(@waiting_game).create_next_round!
    assert_equal "Archived question 2?", second_round.question
  end

  test "does not fill a lobby after another live human joins" do
    add_live_player(@waiting_game, "second-live@example.com")

    assert_no_difference -> { Player.where(is_virtual: true).count } do
      assert_not WaitingGameFiller.new(@waiting_game).fill_and_start!
    end

    assert @waiting_game.reload.waiting?
  end

  test "historical players cast ballots with their original accuracy" do
    WaitingGameFiller.new(@waiting_game).fill_and_start!
    @waiting_game.rounds.destroy_all
    Game::TOTAL_ROUNDS.times do |index|
      @waiting_game.rounds.create!(
        round_number: index + 1,
        question: "Archived question #{index + 1}?",
        status: :completed
      )
    end
    @waiting_game.update!(current_round: Game::TOTAL_ROUNDS)

    CollectVirtualVotesJob.perform_now(@waiting_game)

    assert_equal 4, @waiting_game.votes.count
    @waiting_game.virtual_players.each do |player|
      votes = player.votes_cast.where(game: @waiting_game).includes(:voted_for)
      assert_equal Vote::MAX_VOTES_PER_PLAYER, votes.count
      assert_equal player.historical_correct_ai_guesses, votes.count { |vote| vote.voted_for.is_ai? }
    end

    @waiting_game.ai_players.each do |ai_player|
      @host.votes_cast.create!(game: @waiting_game, voted_for: ai_player)
    end
    assert @waiting_game.voting_complete?
  end

  test "virtual players require complete historical data but not a user account" do
    player = @waiting_game.players.build(is_virtual: true)
    assert_not player.valid?
    assert player.errors[:user].empty?
    assert player.errors[:historical_data].present?
  end

  test "the game API presents historical seats as ordinary human players" do
    WaitingGameFiller.new(@waiting_game).fill_and_start!
    @waiting_game.update!(status: :completed)

    detail = Api::V1::GameSerializer.new(@waiting_game, current_user: @host.user).detail
    historical_players = detail.fetch(:players).select do |player|
      @waiting_game.virtual_players.exists?(id: player.fetch(:id))
    end

    assert_equal 2, historical_players.length
    historical_players.each do |player|
      assert_equal false, player.fetch(:is_ai)
      assert player.fetch(:display_name).present?
      assert_not player.key?(:is_virtual)
    end
  end

  private

  def create_historical_game
    game = Game.create!(status: :completed, current_round: Game::TOTAL_ROUNDS, round_count: Game::TOTAL_ROUNDS)
    players = 2.times.map do |index|
      add_live_player(game, "archive-#{index + 1}@example.com", host: index.zero?)
    end
    game.add_ai_players!

    Game::TOTAL_ROUNDS.times do |round_index|
      round = game.rounds.create!(
        round_number: round_index + 1,
        question: "Archived question #{round_index + 1}?",
        status: :completed
      )
      players.each_with_index do |player, player_index|
        player.answers.create!(
          round: round,
          content: "Human #{player_index + 1} answer #{round_index + 1}",
          submitted_at: Time.current
        )
      end
    end

    players.first.votes_cast.create!(game: game, voted_for: game.ai_players.first)
    players.first.votes_cast.create!(game: game, voted_for: game.ai_players.second)
    players.second.votes_cast.create!(game: game, voted_for: game.ai_players.first)
    players.second.votes_cast.create!(game: game, voted_for: players.first)

    [ game, players ]
  end

  def create_waiting_game
    game = Game.create!(status: :waiting, current_round: 0, round_count: 0)
    host = add_live_player(game, "solo-host@example.com", host: true)
    game.add_ai_players!
    [ game, host ]
  end

  def add_live_player(game, email, host: false)
    user = User.create!(
      email_address: email,
      password: "password123",
      password_confirmation: "password123"
    )
    character = game.assign_next_character
    game.players.create!(
      user: user,
      is_host: host,
      character_name: character.fetch(:name),
      character_avatar: character.fetch(:avatar)
    )
  end
end
