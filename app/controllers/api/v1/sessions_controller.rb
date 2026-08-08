class Api::V1::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate_api_session!, only: :create

  def create
    email = params.require(:email_address).to_s.strip.downcase
    password = params.require(:password).to_s
    user = User.find_by(email_address: email)
    created = false

    if user
      unless user.authenticate(password)
        render_error("Invalid password.", :unauthorized)
        return
      end
    else
      user = User.new(
        email_address: email,
        password: password,
        password_confirmation: password,
        display_name: DisplayNameGenerator.generate
      )
      user.save!
      created = true
    end

    api_session, token = Session.create_with_api_token!(
      user: user,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    Current.session = api_session

    render json: {
      token: token,
      user: Api::V1::UserSerializer.new(user).as_json,
      account_created: created
    }, status: created ? :created : :ok
  end

  def destroy
    Current.session.destroy!
    Current.session = nil
    head :no_content
  end
end
