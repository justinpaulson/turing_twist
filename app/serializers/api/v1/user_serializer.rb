class Api::V1::UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      email_address: @user.email_address,
      display_name: @user.display_name
    }
  end
end
