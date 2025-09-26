require "test_helper"

class RoundsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get rounds_show_url
    assert_response :success
  end

  test "should get submit_answer" do
    get rounds_submit_answer_url
    assert_response :success
  end
end
