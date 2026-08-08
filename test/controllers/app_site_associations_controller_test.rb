require "test_helper"

class AppSiteAssociationsControllerTest < ActionDispatch::IntegrationTest
  test "serves the universal link association without authentication" do
    get "/.well-known/apple-app-site-association"

    assert_response :success
    assert_equal "application/json", response.media_type

    payload = response.parsed_body
    detail = payload.dig("applinks", "details", 0)
    assert_equal [ "H8TX3AP66F.com.justinpaulson.TuringTwist" ], detail["appIDs"]
    assert_equal "/invite/games/*", detail.dig("components", 0, "/")
  end
end
