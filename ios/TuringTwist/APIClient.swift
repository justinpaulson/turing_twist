import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .server(let message): message
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["TURING_TWIST_API_URL"],
           let url = URL(string: override) {
            return url
        }

        let configured = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
        return URL(string: configured ?? "https://turing.justinpaulson.com/api/v1")!
    }

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func signIn(email: String, password: String) async throws -> SessionResponse {
        try await request(
            "session",
            method: "POST",
            body: SignInBody(emailAddress: email, password: password),
            token: nil
        )
    }

    func signOut(token: String) async throws {
        let _: EmptyResponse = try await request("session", method: "DELETE", token: token)
    }

    func profile(token: String) async throws -> UserResponse {
        try await request("profile", token: token)
    }

    func updateProfile(
        displayName: String,
        emailAddress: String,
        password: String?,
        passwordConfirmation: String?,
        token: String
    ) async throws -> UserResponse {
        try await request(
            "profile",
            method: "PATCH",
            body: ProfileBody(
                displayName: displayName,
                emailAddress: emailAddress,
                password: password,
                passwordConfirmation: passwordConfirmation
            ),
            token: token
        )
    }

    func games(token: String) async throws -> GameListResponse {
        try await request("games", token: token)
    }

    func game(id: Int, token: String) async throws -> GameDetail {
        try await request("games/\(id)", token: token)
    }

    func createGame(password: String?, token: String) async throws -> GameDetail {
        try await request(
            "games",
            method: "POST",
            body: PasswordBody(password: password),
            token: token
        )
    }

    func joinGame(id: Int, password: String?, token: String) async throws -> GameDetail {
        try await request(
            "games/\(id)/join",
            method: "POST",
            body: PasswordBody(password: password),
            token: token
        )
    }

    func startGame(id: Int, token: String) async throws -> GameDetail {
        try await request("games/\(id)/start", method: "POST", token: token)
    }

    func submitAnswer(gameID: Int, round: Int, content: String, token: String) async throws -> GameDetail {
        try await request(
            "games/\(gameID)/rounds/\(round)/answer",
            method: "POST",
            body: AnswerBody(content: content),
            token: token
        )
    }

    func advanceRound(gameID: Int, round: Int, token: String) async throws -> GameDetail {
        try await request("games/\(gameID)/rounds/\(round)/advance", method: "POST", token: token)
    }

    func skipToReviewing(gameID: Int, round: Int, token: String) async throws -> GameDetail {
        try await request("games/\(gameID)/rounds/\(round)/skip_to_reviewing", method: "POST", token: token)
    }

    func vote(gameID: Int, playerID: Int, token: String) async throws -> GameDetail {
        try await request(
            "games/\(gameID)/votes",
            method: "POST",
            body: VoteBody(votedForID: playerID),
            token: token
        )
    }

    func skipRemainingVotes(gameID: Int, token: String) async throws -> GameDetail {
        try await request("games/\(gameID)/skip_remaining_votes", method: "POST", token: token)
    }

    private func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        token: String?
    ) async throws -> Response {
        try await perform(path, method: method, encodedBody: nil, token: token)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body,
        token: String?
    ) async throws -> Response {
        try await perform(path, method: method, encodedBody: encoder.encode(body), token: token)
    }

    private func perform<Response: Decodable>(
        _ path: String,
        method: String,
        encodedBody: Data?,
        token: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = encodedBody
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let apiError = try? decoder.decode(APIErrorResponse.self, from: data)
            throw APIClientError.server(apiError?.error ?? "Request failed (\(http.statusCode)).")
        }
        if Response.self == EmptyResponse.self && data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct SignInBody: Encodable {
    let emailAddress: String
    let password: String
}

private struct PasswordBody: Encodable {
    let password: String?
}

private struct AnswerBody: Encodable {
    let content: String
}

private struct VoteBody: Encodable {
    let votedForID: Int

    enum CodingKeys: String, CodingKey {
        case votedForID = "voted_for_id"
    }
}

private struct ProfileBody: Encodable {
    let displayName: String
    let emailAddress: String
    let password: String?
    let passwordConfirmation: String?
}

private struct EmptyResponse: Decodable {}
