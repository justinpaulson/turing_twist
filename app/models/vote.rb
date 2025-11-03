class Vote < ApplicationRecord
  belongs_to :round
  belongs_to :voter, class_name: "Player"
  belongs_to :voted_for, class_name: "Player"

  validate :cannot_vote_for_self
  validate :cannot_vote_for_eliminated_player
  validate :cannot_exceed_vote_limit

  MAX_VOTES_PER_PLAYER = 2

  private

  def cannot_vote_for_self
    errors.add(:voted_for, "cannot vote for yourself") if voter_id == voted_for_id
  end

  def cannot_vote_for_eliminated_player
    if voted_for&.is_eliminated?
      errors.add(:voted_for, "cannot vote for eliminated player")
    end
  end

  def cannot_exceed_vote_limit
    existing_votes = Vote.where(round_id: round_id, voter_id: voter_id).where.not(id: id).count
    if existing_votes >= MAX_VOTES_PER_PLAYER
      errors.add(:base, "cannot vote for more than #{MAX_VOTES_PER_PLAYER} players")
    end
  end
end
