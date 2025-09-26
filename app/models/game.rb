class Game < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :rounds, dependent: :destroy
  has_many :users, through: :players

  enum :status, { waiting: 0, active: 1, completed: 2 }

  MIN_PLAYERS = 5
  MAX_PLAYERS = 8
  AI_PLAYERS_COUNT = 2

  def current_round_object
    rounds.find_by(round_number: current_round)
  end

  def human_players
    players.where(is_ai: false)
  end

  def ai_players
    players.where(is_ai: true)
  end

  def active_players
    players.where(is_eliminated: false)
  end

  def active_ai_players
    players.where(is_ai: true, is_eliminated: false)
  end

  def active_human_players
    players.where(is_ai: false, is_eliminated: false)
  end

  def can_start?
    players.count >= MIN_PLAYERS && players.count <= MAX_PLAYERS
  end

  def add_ai_players!
    AI_PLAYERS_COUNT.times do |i|
      players.create!(
        is_ai: true,
        ai_persona: generate_ai_persona(i)
      )
    end
  end

  private

  def generate_ai_persona(index)
    personas = [
      "You are a friendly and casual person who likes to share personal stories.",
      "You are thoughtful and introspective, often reflecting on deeper meanings."
    ]
    personas[index]
  end
end
