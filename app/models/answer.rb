class Answer < ApplicationRecord
  belongs_to :round
  belongs_to :player

  validates :content, presence: true
  validates :player_id, uniqueness: { scope: :round_id }
end
