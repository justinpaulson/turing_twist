class Game < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :rounds, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :users, through: :players

  broadcasts_refreshes

  enum :status, { waiting: 0, active: 1, completed: 2 }

  MIN_PLAYERS = 5
  MAX_PLAYERS = 8
  AI_PLAYERS_COUNT = 2
  TOTAL_ROUNDS = 5

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

  def private?
    password.present?
  end

  def valid_password?(input_password)
    return true unless private?
    password == input_password
  end

  def add_ai_players!
    AI_PLAYERS_COUNT.times do |i|
      character = assign_next_character
      players.create!(
        is_ai: true,
        ai_persona: generate_ai_persona(i),
        character_name: character[:name],
        character_avatar: character[:avatar]
      )
    end
  end

  def assign_next_character
    used_indices = players.pluck(:character_avatar).compact.map { |avatar|
      Player::CHARACTERS.index { |c| c[:avatar] == avatar }
    }.compact

    available_indices = (0...Player::CHARACTERS.length).to_a - used_indices
    character_index = available_indices.sample

    Player::CHARACTERS[character_index]
  end

  def points_per_correct_guess
    players.count <= 6 ? 2 : 3
  end

  def max_points_from_guesses
    points_per_correct_guess * AI_PLAYERS_COUNT
  end

  def all_rounds_complete?
    answering_rounds = rounds.where("round_number <= ?", TOTAL_ROUNDS)
    answering_rounds.count >= TOTAL_ROUNDS && answering_rounds.all?(&:completed?)
  end

  def voting_complete?
    # Only human players vote - each should vote for 2 players
    expected_count = active_human_players.count * Vote::MAX_VOTES_PER_PLAYER
    actual_count = votes.count
    expected_count > 0 && actual_count >= expected_count
  end

  private

  def generate_ai_persona(index)
    # Define 6 distinct personality styles
    all_personas = [
      # 1. The Grammar Perfectionist
      "Use proper grammar and punctuation. Never use abbreviations or emojis. Answer directly and concisely.",

      # 2. The Lowercase Casual
      "type in lowercase. use abbreviations: lol, tbh, ngl, idk, etc. casual texting vibe. sometimes skip punctuation",

      # 3. The Sarcastic One
      "Be sarcastic and witty. Answer with dry humor or irony when possible. Keep it clever and brief.",

      # 4. The Enthusiast
      "Show excitement! Use exclamation points! Maybe an emoji or two max. Be genuinely enthusiastic but brief.",

      # 5. The Minimalist
      "Minimal words. Short. Direct. No extra details. Just answer the question.",

      # 6. The Meta-Gamer
      "Joke about being an AI/bot as reverse psychology. Make meta references. Be playfully self-aware about the game."
    ]

    # Store selected personas for this game if not already set
    unless ai_persona_indices
      # Randomly select 2 different indices
      selected = all_personas.each_index.to_a.sample(AI_PLAYERS_COUNT)
      update_column(:ai_persona_indices, selected)
    end

    all_personas[ai_persona_indices[index]]
  end
end
