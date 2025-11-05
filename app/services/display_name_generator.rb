class DisplayNameGenerator
  COLORS = [
    "Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Pink", "Teal",
    "Crimson", "Azure", "Emerald", "Golden", "Violet", "Amber", "Coral",
    "Indigo", "Scarlet", "Navy", "Lime", "Magenta", "Turquoise", "Silver"
  ].freeze

  ANIMALS = [
    "Wolf", "Bear", "Eagle", "Tiger", "Lion", "Hawk", "Fox", "Owl",
    "Raven", "Falcon", "Dragon", "Phoenix", "Panda", "Lynx", "Orca",
    "Jaguar", "Cobra", "Shark", "Panther", "Rhino", "Cheetah", "Badger"
  ].freeze

  def self.generate
    "#{COLORS.sample} #{ANIMALS.sample}"
  end
end
