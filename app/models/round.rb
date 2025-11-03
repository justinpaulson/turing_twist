class Round < ApplicationRecord
  belongs_to :game
  has_many :answers, dependent: :destroy

  enum :status, { answering: 0, reviewing: 1, voting: 2, completed: 3 }

  # Use round_number in URLs instead of id
  def to_param
    round_number.to_s
  end

  QUESTIONS = [
    "What's your favorite color and why does it matter?",
    "Why are dogs better than cats (or are they)?",
    "Pineapple on pizza - defend your position.",
    "Why are you a morning person or night owl?",
    "What's your weirdest habit that would make people judge you?",
    "Coffee or tea and why is the other one terrible?",
    "What's your guilty pleasure song that you're embarrassed about?",
    "Beach or mountains and why is the other boring?",
    "What's your phone wallpaper right now and why?",
    "Sweet or savory - why are you choosing wrong?",
    "What's the last embarrassing thing you googled?",
    "Socks with sandals: defend it or roast it.",
    "What's your worst cooking disaster story?",
    "What's a popular opinion that you actually disagree with?",
    "What emoji do you overuse and why?"
  ]

  def self.generate_question(game)
    # Get all previously used questions in this game
    used_questions = game.rounds.pluck(:question)

    # Get available questions that haven't been used yet
    available_questions = QUESTIONS - used_questions

    # If we've used all questions, start over (shouldn't happen with 15 questions and 5 rounds)
    available_questions = QUESTIONS if available_questions.empty?

    available_questions.sample
  end

  def all_players_answered?
    expected_count = game.active_players.count
    actual_count = answers.count
    expected_count > 0 && actual_count >= expected_count
  end
end
