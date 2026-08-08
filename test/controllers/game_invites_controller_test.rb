require "test_helper"

class GameInvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:one)
  end

  test "shows an unauthenticated web fallback before the App Store listing exists" do
    get game_invite_url(@game)

    assert_response :success
    assert_select "h1", text: "TURING TWIST"
    assert_select ".invite-game-number", text: "GAME ##{@game.id}"
    assert_select "a[href='#{game_path(@game)}']", text: /CONTINUE ON THE WEB/
  end

  test "redirects users without the app to the configured App Store listing" do
    previous_url = ENV["IOS_APP_STORE_URL"]
    ENV["IOS_APP_STORE_URL"] = "https://apps.apple.com/app/turing-twist/id1234567890"

    get game_invite_url(@game)

    assert_redirected_to "https://apps.apple.com/app/turing-twist/id1234567890"
  ensure
    ENV["IOS_APP_STORE_URL"] = previous_url
  end
end
