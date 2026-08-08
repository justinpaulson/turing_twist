class GameInvitesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_game

  def show
    if (url = app_store_url)
      redirect_to url, allow_other_host: true
    end
  end

  private
    def set_game
      @game = Game.find(params[:id])
    end

    def app_store_url
      value = ENV["IOS_APP_STORE_URL"].presence ||
        Rails.application.credentials.dig(:ios, :app_store_url).presence
      return unless value

      uri = URI.parse(value)
      value if uri.scheme == "https" && uri.host == "apps.apple.com"
    rescue URI::InvalidURIError
      nil
    end
end
