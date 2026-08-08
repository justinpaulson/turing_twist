class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_session!

  rescue_from ActiveRecord::RecordNotFound do
    render_error("Not found.", :not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error(error.record.errors.full_messages.to_sentence, :unprocessable_entity)
  end

  private

  def authenticate_api_session!
    token = request.authorization.to_s.delete_prefix("Bearer ").strip
    Current.session = Session.find_by_api_token(token)
    render_error("Authentication required.", :unauthorized) unless Current.session
  end

  def current_user
    Current.user
  end

  def render_error(message, status)
    render json: { error: message }, status: status
  end

  def render_game(game, status: :ok, message: nil)
    body = Api::V1::GameSerializer.new(game, current_user: current_user).detail
    body[:message] = message if message.present?
    render json: body, status: status
  end
end
