require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index without authentication" do
    get root_url
    assert_response :success
    assert_select "h1", text: /TURING TWIST/
    assert_select "a", text: /SIGN IN/
    assert_select "a", text: /VIEW GAMES/
  end

  test "should show authenticated actions when signed in" do
    user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post session_url, params: { email_address: user.email_address, password: "password123" }

    get root_url
    assert_response :success
    assert_select "a", text: /VIEW GAMES/
    assert_select "a", text: /NEW GAME/
  end

  test "should display game statistics" do
    get root_url
    assert_response :success
    assert_select "div", text: /Players:.*Games:/
  end
end
