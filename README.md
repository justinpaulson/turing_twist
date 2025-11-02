# Turing Twist 🤖🎮

A social deduction party game where players try to identify AI players among human participants. Inspired by the Turing Test, players answer personal questions and vote on who they think is human or AI.

## Design Theme

Turing Twist features a **black and white newspaper style** with **old school Nintendo graphics** aesthetic. The visual design combines the classic look of newspaper print with retro 8-bit gaming elements, creating a unique vintage computing experience. See `claude.md` for detailed design system documentation.

## Game Overview

Turing Twist is a multiplayer web game that challenges players to distinguish between human and AI responses. Each game consists of 5 rounds where:
1. Players answer personal questions
2. Everyone reads all anonymous responses
3. Players vote for who they think the 2 AI players are
4. Points are awarded for correct AI identifications
5. Bonus points for fooling other players into thinking you're an AI!

The twist? There are always 2 AI players in the mix, powered by LLM technology, making their responses surprisingly human-like! After 5 rounds, the player with the highest score wins!

## Features

- **Real-time multiplayer gameplay** - 5-8 players per game
- **AI integration** - 2 AI players with unique personas in every game
- **Session-based authentication** - Secure user sessions with bcrypt
- **Points-based scoring** - Score points for identifying AIs and fooling other players
- **Diverse question pool** - 15+ thought-provoking personal questions
- **Modern Rails stack** - Built with Rails 8, Hotwire, and Stimulus

## Tech Stack

- **Ruby** 3.3.4
- **Rails** 8.0.3
- **Database** SQLite3
- **Frontend** Hotwire (Turbo + Stimulus) with Import Maps
- **AI Integration** ruby_llm gem
- **Authentication** Rails built-in authentication with bcrypt
- **Deployment** Docker-ready with Kamal support

## Prerequisites

- Ruby 3.3.4 or higher
- Rails 8.0.3 or higher
- SQLite3
- Bundler
- Node.js (for JavaScript runtime)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/turing_twist.git
cd turing_twist
```

2. Install dependencies:
```bash
bundle install
```

3. Set up the database:
```bash
rails db:create
rails db:migrate
rails db:seed  # Optional: adds sample data
```

4. Configure AI integration (if using ruby_llm):
```bash
# Add your LLM API credentials to credentials
rails credentials:edit
```

Add:
```yaml
llm:
  api_key: your_api_key_here
  model: gpt-4  # or your preferred model
```

## Running the Application

### Development Mode

**IMPORTANT**: You must use `bin/dev` to run the application in development. This starts both the Rails server AND the background jobs worker (required for AI players to answer questions and vote).

```bash
# Start the Rails server with background jobs (REQUIRED)
bin/dev
```

This will start:
- Rails server on port 3077
- Solid Queue background jobs worker (for AI player actions)

Visit `http://localhost:3077` to play!

**Note**: Running just `rails server` will NOT work properly - AI players won't answer or vote without the background jobs worker running.

### Running Tests

```bash
# Run the full test suite
rails test

# Run specific test files
rails test test/models/game_test.rb

# Run system tests
rails test:system
```

### Code Quality

```bash
# Run RuboCop for code style
bundle exec rubocop

# Run Brakeman for security analysis
bundle exec brakeman
```

## How to Play

1. **Create an Account** - Sign up with email and password
2. **Start or Join a Game** - Create a new game room or join an existing one
3. **Wait for Players** - Games need 5-8 players to start (including 2 AI players)
4. **Answer Questions** - Each round presents a personal question to answer
5. **Vote on Responses** - Read all anonymous answers and vote for who you think the 2 AIs are
6. **Score Points** - Earn points for correctly identifying AI responses and fooling other players
7. **Complete 5 Rounds** - Play through all 5 rounds of questions and voting
8. **Win the Game** - Have the highest score at the end!

## Game Rules

- **Minimum Players**: 5 (including 2 AI)
- **Maximum Players**: 8 (including 2 AI)
- **AI Players**: Always 2 per game
- **Total Rounds**: 5 rounds per game
- **Scoring**:
  - 5-6 players: 2 points per correct AI guess (max 4 points/round)
  - 7-8 players: 3 points per correct AI guess (max 6 points/round)
  - 1 point for each vote received as an AI (humans only - deception bonus!)
- **Victory**: Player with the highest score after 5 rounds wins

## Project Structure

```
turing_twist/
├── app/
│   ├── controllers/     # Game logic and request handling
│   ├── models/          # Game, Player, Round, Answer, Vote models
│   ├── views/           # ERB templates for UI
│   └── javascript/      # Stimulus controllers
├── config/              # Rails configuration
├── db/                  # Database schema and migrations
├── test/                # Test suite
└── public/              # Static assets
```

## Key Models

- **Game** - Manages game state and players
- **Player** - Represents human or AI participants
- **Round** - Handles questions and voting phases
- **Answer** - Stores player responses to questions
- **Vote** - Records voting decisions
- **User** - Manages authentication and profiles

## Deployment

### Docker Deployment

```bash
# Build the Docker image
docker build -t turing_twist .

# Run with Docker
docker run -p 3000:3000 turing_twist
```

### Kamal Deployment

```bash
# Configure deploy settings in config/deploy.yml
kamal setup
kamal deploy
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by the Turing Test concept by Alan Turing
- Built with Ruby on Rails and the amazing Rails community
- AI responses powered by modern LLM technology
