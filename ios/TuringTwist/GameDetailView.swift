import SwiftUI

struct GameDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    let gameID: Int
    @State private var game: GameDetail?
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        ZStack {
            HalftoneBackground()
            VStack(spacing: 0) {
                HStack {
                    NewsprintBackButton { dismiss() }
                    Spacer()
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity)

                ZStack {
                    if let game {
                        ScrollView {
                            VStack(spacing: 18) {
                                gameHeader(game)
                                if let errorMessage { ErrorBanner(message: errorMessage) }

                                switch game.phase {
                                case .waiting:
                                    WaitingRoomView(game: game, isWorking: isWorking) {
                                        await startGame()
                                    }
                                case .answering, .reviewing:
                                    if let round = game.round {
                                        RoundView(
                                            game: game,
                                            round: round,
                                            isWorking: isWorking,
                                            submit: submitAnswer,
                                            advance: advanceRound,
                                            skip: skipRound
                                        )
                                    }
                                case .voting:
                                    if let voting = game.voting {
                                        VotingView(
                                            game: game,
                                            voting: voting,
                                            isWorking: isWorking,
                                            vote: castVote,
                                            finishVoting: finishVoting
                                        )
                                    }
                                case .completed:
                                    ResultsView(game: game)
                                case .active:
                                    LoadingView().padding(.vertical, 50)
                                }
                            }
                            .frame(maxWidth: 920)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                        }
                        .refreshable { await refresh() }
                    } else if let errorMessage {
                        VStack(spacing: 18) {
                            ErrorBanner(message: errorMessage)
                            Button("TRY AGAIN") { Task { await refresh() } }
                                .buttonStyle(PixelButtonStyle())
                        }
                        .padding()
                        .frame(maxWidth: 600)
                    } else {
                        LoadingView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: gameID) {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await refresh(silent: true)
            }
        }
    }

    private func gameHeader(_ game: GameDetail) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("TURING TWIST")
                    .font(Newsprint.headline(22))
                    .tracking(1.5)
                Text("GAME #\(game.id)  •  \(game.phase.rawValue.uppercased())")
                    .font(Newsprint.mono(11, weight: .bold))
            }
            Spacer()
            if game.phase != .waiting && game.phase != .completed {
                Text("\(min(game.currentRound, game.totalRounds))/\(game.totalRounds)")
                    .font(Newsprint.mono(18, weight: .black))
                    .padding(9)
                    .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 3))
            }
        }
        .newsprintCard(padding: 14)
    }

    private func refresh(silent: Bool = false) async {
        guard let token = session.token else { return }
        do {
            game = try await APIClient.shared.game(id: gameID, token: token)
            if !silent { errorMessage = nil }
        } catch {
            if !silent || game == nil { errorMessage = error.localizedDescription }
        }
    }

    private func run(_ operation: (String) async throws -> GameDetail) async -> Bool {
        guard let token = session.token, !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            game = try await operation(token)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func startGame() async -> Bool {
        await run { try await APIClient.shared.startGame(id: gameID, token: $0) }
    }

    private func submitAnswer(_ content: String) async -> Bool {
        guard let round = game?.round?.number else { return false }
        return await run {
            try await APIClient.shared.submitAnswer(gameID: gameID, round: round, content: content, token: $0)
        }
    }

    private func advanceRound() async -> Bool {
        guard let round = game?.round?.number else { return false }
        return await run {
            try await APIClient.shared.advanceRound(gameID: gameID, round: round, token: $0)
        }
    }

    private func skipRound() async -> Bool {
        guard let round = game?.round?.number else { return false }
        return await run {
            try await APIClient.shared.skipToReviewing(gameID: gameID, round: round, token: $0)
        }
    }

    private func castVote(_ playerID: Int) async -> Bool {
        await run { try await APIClient.shared.vote(gameID: gameID, playerID: playerID, token: $0) }
    }

    private func finishVoting() async -> Bool {
        await run { try await APIClient.shared.skipRemainingVotes(gameID: gameID, token: $0) }
    }
}

private struct WaitingRoomView: View {
    let game: GameDetail
    let isWorking: Bool
    let start: () async -> Bool

    var body: some View {
        VStack(spacing: 18) {
            if game.isHost {
                hostControls
            }

            if let player = game.currentPlayer {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { avatar(player); identity(player) }
                    VStack(spacing: 0) { avatar(player); identity(player) }
                }
                .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
            }

            VStack(spacing: 9) {
                Text("\(game.playerCount) / \(game.maxPlayers)")
                    .font(Newsprint.mono(52, weight: .black))
                    .minimumScaleFactor(0.7)
                Text("PLAYERS JOINED")
                    .font(Newsprint.headline(20))
                    .tracking(2)
                Rectangle().frame(height: 3).padding(.vertical, 5)
                if game.waitingFor > 0 {
                    Text("⌛ WAITING FOR PLAYERS")
                        .font(Newsprint.mono(15, weight: .bold))
                    Text("► NEED \(game.waitingFor) MORE")
                        .font(Newsprint.mono(12))
                } else if game.isHost {
                    Text("■ READY TO START!")
                        .font(Newsprint.mono(15, weight: .bold))
                } else {
                    Text("⌛ WAITING FOR HOST TO START")
                        .font(Newsprint.mono(14, weight: .bold))
                }
            }
            .newsprintCard(padding: 24)

            rules
        }
    }

    private var hostControls: some View {
        VStack(alignment: .leading, spacing: 15) {
            BoxHeader(title: "★ Host Controls", inverted: false)
            Text("INVITE FRIENDS TO GAME #\(game.id)")
                .font(Newsprint.mono(13, weight: .bold))
            if let password = game.invitePassword {
                Text("■ PRIVATE GAME  •  PASSWORD: \(password)")
                    .font(Newsprint.mono(12, weight: .bold))
                    .padding(12)
                    .overlay(Rectangle().stroke(Newsprint.paper, lineWidth: 2))
            }
            ShareLink(
                item: inviteURL,
                subject: Text("Join my Turing Twist game"),
                message: Text(shareMessage)
            ) {
                Text("SHARE INVITE")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Newsprint.paper)
                    .foregroundStyle(Newsprint.ink)
                    .overlay(Rectangle().stroke(Newsprint.paper, lineWidth: 3))
            }
            .font(Newsprint.mono(14, weight: .bold))

            if game.playerCount >= game.minPlayers {
                Button(isWorking ? "STARTING…" : "START GAME") {
                    Task { _ = await start() }
                }
                .buttonStyle(PixelButtonStyle())
                .disabled(isWorking)
            }
        }
        .padding(18)
        .foregroundStyle(Newsprint.paper)
        .background(Newsprint.ink)
        .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
    }

    private var shareMessage: String {
        if let password = game.invitePassword {
            "Join game #\(game.id). Password: \(password)"
        } else {
            "Join game #\(game.id)."
        }
    }

    private var inviteURL: URL {
        URL(string: "https://turing.justinpaulson.com/invite/games/\(game.id)")!
    }

    private func avatar(_ player: Player) -> some View {
        CharacterAvatar(name: player.characterAvatar, size: 180)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 210)
            .background(Newsprint.ink)
    }

    private func identity(_ player: Player) -> some View {
        VStack(spacing: 10) {
            Text("► YOU ARE").font(Newsprint.mono(12, weight: .bold)).tracking(2)
            Text(player.characterName.uppercased())
                .font(Newsprint.headline(34))
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Newsprint.paper)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 0) {
            BoxHeader(title: "► How to Play")
            rule("1", "ANSWER 5 QUESTIONS", "Everyone—including two hidden AIs—answers each prompt.")
            rule("2", "VOTE FOR 2 AIS", "Review every answer and identify the machines.")
            rule("3", "SCORE POINTS", "Earn points for correct guesses and deceiving other players.")
        }
        .newsprintCard(padding: 0)
    }

    private func rule(_ number: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(Newsprint.mono(18, weight: .black))
                .foregroundStyle(Newsprint.paper)
                .frame(width: 42, height: 42)
                .background(Newsprint.ink)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(Newsprint.headline(17))
                Text(body).font(Newsprint.mono(12))
            }
        }
        .padding(16)
    }
}
