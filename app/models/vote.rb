class Vote < ApplicationRecord
  belongs_to :round
  belongs_to :voter, class_name: "Player"
  belongs_to :voted_for, class_name: "Player"

  validates :voter_id, uniqueness: { scope: :round_id }
  validate :cannot_vote_for_self
  validate :cannot_vote_for_eliminated_player

  private

  def cannot_vote_for_self
    errors.add(:voted_for, "cannot vote for yourself") if voter_id == voted_for_id
  end

  def cannot_vote_for_eliminated_player
    if voted_for&.is_eliminated?
      errors.add(:voted_for, "cannot vote for eliminated player")
    end
  end
end
