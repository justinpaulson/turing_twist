class Round < ApplicationRecord
  belongs_to :game
  has_many :answers, dependent: :destroy
  has_many :votes, dependent: :destroy

  enum :status, { answering: 0, voting: 1, completed: 2 }

  QUESTIONS = [
    "What is your favorite childhood memory?",
    "If you could have dinner with anyone from history, who would it be and why?",
    "What's the most embarrassing thing that ever happened to you?",
    "What would you do if you won the lottery tomorrow?",
    "Describe your perfect day from start to finish.",
    "What's a secret talent you have that most people don't know about?",
    "If you could live anywhere in the world, where would it be and why?",
    "What's the best advice you've ever received?",
    "What fear would you like to overcome?",
    "What makes you feel most alive?",
    "If you could change one thing about the world, what would it be?",
    "What's your biggest regret in life?",
    "Describe a time when you felt truly proud of yourself.",
    "What's the most spontaneous thing you've ever done?",
    "If you could master any skill instantly, what would it be?"
  ]

  def self.generate_question
    QUESTIONS.sample
  end

  def all_players_answered?
    expected_count = game.active_players.count
    actual_count = answers.count
    expected_count > 0 && actual_count >= expected_count
  end

  def voting_complete?
    expected_count = game.active_players.count
    actual_count = votes.count
    expected_count > 0 && actual_count >= expected_count
  end
end
