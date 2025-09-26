class Player < ApplicationRecord
  belongs_to :game
  belongs_to :user, optional: true
  has_many :answers, dependent: :destroy
  has_many :votes_cast, class_name: "Vote", foreign_key: "voter_id", dependent: :destroy
  has_many :votes_received, class_name: "Vote", foreign_key: "voted_for_id", dependent: :destroy

  validates :user, presence: true, unless: :is_ai?
  validates :ai_persona, presence: true, if: :is_ai?

  def name
    if is_ai?
      "Player #{id}"
    else
      user.email_address.split('@').first.capitalize
    end
  end
end
