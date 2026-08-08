class Player < ApplicationRecord
  belongs_to :game, touch: true
  belongs_to :user, optional: true
  has_many :answers, dependent: :destroy
  has_many :votes_cast, class_name: "Vote", foreign_key: "voter_id", dependent: :destroy
  has_many :votes_received, class_name: "Vote", foreign_key: "voted_for_id", dependent: :destroy

  validates :user, presence: true, unless: -> { is_ai? || is_virtual? }
  validates :ai_persona, presence: true, if: :is_ai?
  validate :player_type_is_consistent
  validate :historical_data_is_complete, if: :is_virtual?

  CHARACTERS = [
    { name: "The Knight", avatar: "knight.svg" },
    { name: "The Wizard", avatar: "wizard.svg" },
    { name: "The Rogue", avatar: "rogue.svg" },
    { name: "The Warrior", avatar: "warrior.svg" },
    { name: "The Archer", avatar: "archer.svg" },
    { name: "The Priest", avatar: "priest.svg" },
    { name: "The Barbarian", avatar: "barbarian.svg" },
    { name: "The Scholar", avatar: "scholar.svg" },
    { name: "The Paladin", avatar: "paladin.svg" },
    { name: "The Bard", avatar: "bard.svg" },
    { name: "The Monk", avatar: "monk.svg" },
    { name: "The Necromancer", avatar: "necromancer.svg" },
    { name: "The Druid", avatar: "druid.svg" },
    { name: "The Assassin", avatar: "assassin.svg" }
  ].freeze

  def name
    if is_ai?
      "Player #{id}"
    elsif is_virtual?
      public_display_name
    else
      user.email_address.split("@").first.capitalize
    end
  end

  def public_display_name
    return historical_data&.dig("display_name").presence || "Guest Player" if is_virtual?

    user&.display_name.presence || user&.email_address
  end

  def historical_answers
    Array(historical_data&.dig("answers"))
  end

  def historical_answer_for(round_number)
    historical_answers.find { |answer| answer["round_number"].to_i == round_number.to_i }
  end

  def historical_correct_ai_guesses
    historical_data&.dig("correct_ai_guesses").to_i.clamp(0, Vote::MAX_VOTES_PER_PLAYER)
  end

  def character_avatar_path
    "characters/#{character_avatar}" if character_avatar
  end

  private

  def player_type_is_consistent
    errors.add(:base, "a player cannot be both AI and virtual") if is_ai? && is_virtual?
  end

  def historical_data_is_complete
    if historical_answers.length != Game::TOTAL_ROUNDS
      errors.add(:historical_data, "must contain #{Game::TOTAL_ROUNDS} answers")
      return
    end

    historical_answers.each_with_index do |answer, index|
      expected_round = index + 1
      unless answer["round_number"].to_i == expected_round && answer["question"].present? && answer["content"].present?
        errors.add(:historical_data, "contains an invalid answer for round #{expected_round}")
      end
    end
  end
end
