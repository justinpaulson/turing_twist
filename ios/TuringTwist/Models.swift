import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: Int
    var emailAddress: String
    var displayName: String?
}

struct SessionResponse: Decodable {
    let token: String
    let user: User
    let accountCreated: Bool
}

struct UserResponse: Decodable {
    let user: User
    let message: String?
}

struct GameListResponse: Decodable {
    let activeGames: [GameSummary]
    let myGames: [GameSummary]
}

struct GameSummary: Codable, Identifiable, Hashable {
    let id: Int
    let status: String
    let phase: GamePhase
    let isPrivate: Bool
    let playerCount: Int
    let minPlayers: Int
    let maxPlayers: Int
    let waitingFor: Int
    let currentRound: Int
    let totalRounds: Int
    let isMember: Bool
    let isHost: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, phase, playerCount, minPlayers, maxPlayers, waitingFor
        case currentRound, totalRounds, isMember, isHost, createdAt
        case isPrivate = "private"
    }
}

enum GamePhase: String, Codable, Hashable {
    case waiting
    case answering
    case reviewing
    case voting
    case completed
    case active
}

struct GameDetail: Decodable, Identifiable {
    let id: Int
    let status: String
    let phase: GamePhase
    let isPrivate: Bool
    let playerCount: Int
    let minPlayers: Int
    let maxPlayers: Int
    let waitingFor: Int
    let currentRound: Int
    let totalRounds: Int
    let isMember: Bool
    let isHost: Bool
    let createdAt: Date
    let currentPlayerId: Int?
    let invitePassword: String?
    let pointsPerCorrectGuess: Int
    let players: [Player]
    let round: RoundSnapshot?
    let voting: VotingSnapshot?
    let leaderboard: [LeaderboardEntry]?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case id, status, phase, playerCount, minPlayers, maxPlayers, waitingFor
        case currentRound, totalRounds, isMember, isHost, createdAt, currentPlayerId
        case invitePassword, pointsPerCorrectGuess, players, round, voting, leaderboard, message
        case isPrivate = "private"
    }

    var currentPlayer: Player? {
        players.first(where: { $0.id == currentPlayerId })
    }
}

struct Player: Decodable, Identifiable {
    let id: Int
    let characterName: String
    let characterAvatar: String?
    let isCurrentPlayer: Bool
    let isHost: Bool
    let isAI: Bool?
    let displayName: String?
    let score: Int?
}

struct RoundSnapshot: Decodable {
    let number: Int
    let status: GamePhase
    let question: String
    let answerCount: Int
    let totalPlayers: Int
    let myAnswer: String?
    let answers: [GameAnswer]
}

struct GameAnswer: Decodable, Identifiable {
    let id: Int
    let playerId: Int
    let roundNumber: Int
    let question: String
    let content: String
}

struct VotingSnapshot: Decodable {
    let candidates: [VotingCandidate]
    let votedForIds: [Int]
    let votesRemaining: Int
    let votesCast: Int
    let votesExpected: Int
    let playersFinished: Int
    let humanPlayers: Int
    let startedAt: Date?
}

struct VotingCandidate: Decodable, Identifiable {
    var id: Int { playerId }
    let playerId: Int
    let characterName: String
    let characterAvatar: String?
    let isCurrentPlayer: Bool
    let hasVote: Bool
    let answers: [GameAnswer]
}

struct LeaderboardEntry: Decodable, Identifiable {
    var id: Int { playerId }
    let playerId: Int
    let characterName: String
    let characterAvatar: String?
    let displayName: String
    let isCurrentPlayer: Bool
    let isAI: Bool
    let score: Int
    let correctVotes: Int
    let votesReceived: Int
    let pointsFromGuesses: Int
    let pointsFromDeception: Int
    let answers: [GameAnswer]
}

struct APIErrorResponse: Decodable {
    let error: String
}
