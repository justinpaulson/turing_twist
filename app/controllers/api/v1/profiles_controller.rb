class Api::V1::ProfilesController < Api::V1::BaseController
  def show
    render json: { user: Api::V1::UserSerializer.new(current_user).as_json }
  end

  def update
    attributes = params.permit(:display_name, :email_address, :password, :password_confirmation)
    if attributes[:password].blank?
      attributes.delete(:password)
      attributes.delete(:password_confirmation)
    end

    if current_user.update(attributes)
      render json: {
        user: Api::V1::UserSerializer.new(current_user).as_json,
        message: "Profile updated."
      }
    else
      render_error(current_user.errors.full_messages.to_sentence, :unprocessable_entity)
    end
  end
end
