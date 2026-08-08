class Session < ApplicationRecord
  belongs_to :user

  def self.create_with_api_token!(user:, user_agent:, ip_address:)
    token = SecureRandom.urlsafe_base64(48)
    session = user.sessions.create!(
      user_agent: user_agent,
      ip_address: ip_address,
      api_token_digest: digest_api_token(token)
    )

    [ session, token ]
  end

  def self.find_by_api_token(token)
    return if token.blank?

    find_by(api_token_digest: digest_api_token(token))
  end

  def self.digest_api_token(token)
    Digest::SHA256.hexdigest(token)
  end
end
