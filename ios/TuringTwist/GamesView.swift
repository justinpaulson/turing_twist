import SwiftUI

struct GamesView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var deepLinks: DeepLinkRouter
    @State private var activeGames: [GameSummary] = []
    @State private var myGames: [GameSummary] = []
    @State private var selectedTab = 0
    @State private var path: [AppRoute] = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showingCreateGame = false
    @State private var showingJoinGame = false
    @State private var invitedGameID: Int?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                HalftoneBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        HStack(alignment: .top, spacing: 12) {
                            Masthead(compact: true)
                            ProfileLinkButton(user: session.user) {
                                if path.last != .profile { path.append(.profile) }
                            }
                        }
                        SectionHeadline(title: "AI Detection Game")

                        Text("Join a game where humans and AIs answer questions, then decide who's real and who's artificial.")
                            .font(Newsprint.mono(14))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let errorMessage { ErrorBanner(message: errorMessage) }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 14) {
                                Button("+ CREATE GAME") { showingCreateGame = true }
                                    .buttonStyle(PixelButtonStyle(filled: true))
                                Button("► JOIN BY NUMBER") { showJoinSheet() }
                                    .buttonStyle(PixelButtonStyle())
                            }
                            VStack(spacing: 14) {
                                Button("+ CREATE GAME") { showingCreateGame = true }
                                    .buttonStyle(PixelButtonStyle(filled: true))
                                Button("► JOIN BY NUMBER") { showJoinSheet() }
                                    .buttonStyle(PixelButtonStyle())
                            }
                        }

                        tabPicker

                        if isLoading {
                            LoadingView().padding(.vertical, 50)
                        } else {
                            gameGrid
                        }
                    }
                    .frame(maxWidth: 920)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await loadGames() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .game(let gameID):
                    GameDetailView(gameID: gameID)
                case .profile:
                    ProfileView()
                }
            }
            .sheet(isPresented: $showingCreateGame) {
                CreateGameSheet(isCreating: $isCreating) { password in
                    await createGame(password: password)
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingJoinGame, onDismiss: { invitedGameID = nil }) {
                JoinGameSheet(initialGameID: invitedGameID) { gameID, password in
                    await join(gameID: gameID, password: password)
                }
                .id(invitedGameID)
                .presentationDetents([.medium])
            }
            .task {
                await loadGames()
                openPendingGameLink()
            }
            .onChange(of: deepLinks.revision) { _, _ in
                if !isLoading { openPendingGameLink() }
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: -4) {
            tabButton("ACTIVE GAMES", index: 0)
            tabButton("MY GAMES", index: 1)
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Rectangle().frame(height: 4) }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            Text(title)
                .font(Newsprint.mono(13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(selectedTab == index ? Newsprint.paper : Newsprint.ink)
                .background(selectedTab == index ? Newsprint.ink : Newsprint.paper)
                .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }

    @ViewBuilder
    private var gameGrid: some View {
        let games = selectedTab == 0 ? activeGames : myGames
        if games.isEmpty {
            Text(selectedTab == 0
                 ? "NO ACTIVE GAMES. CREATE ONE TO GET STARTED!"
                 : "YOU HAVEN'T JOINED ANY GAMES YET.")
                .font(Newsprint.mono(15, weight: .bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .newsprintCard(padding: 32)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ForEach(games) { game in
                    GameCard(game: game, isMine: selectedTab == 1) {
                        Task {
                            if game.isMember {
                                path.append(.game(game.id))
                            } else {
                                await join(game)
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadGames() async {
        guard let token = session.token else { return }
        do {
            let response = try await APIClient.shared.games(token: token)
            activeGames = response.activeGames
            myGames = response.myGames
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func showJoinSheet() {
        invitedGameID = nil
        showingJoinGame = true
    }

    private func openPendingGameLink() {
        guard let gameID = deepLinks.consumeGameID() else { return }

        showingCreateGame = false
        if myGames.contains(where: { $0.id == gameID }) {
            showingJoinGame = false
            invitedGameID = nil
            if path.last != .game(gameID) { path = [ .game(gameID) ] }
        } else {
            invitedGameID = gameID
            showingJoinGame = true
        }
    }

    private func join(_ game: GameSummary) async {
        _ = await join(gameID: game.id, password: nil)
    }

    private func join(gameID: Int, password: String?) async -> Bool {
        guard let token = session.token else { return false }
        do {
            _ = try await APIClient.shared.joinGame(id: gameID, password: password, token: token)
            showingJoinGame = false
            await loadGames()
            path.append(.game(gameID))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func createGame(password: String?) async -> Bool {
        guard let token = session.token else { return false }
        isCreating = true
        defer { isCreating = false }
        do {
            let game = try await APIClient.shared.createGame(password: password, token: token)
            showingCreateGame = false
            await loadGames()
            path.append(.game(game.id))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private enum AppRoute: Hashable {
    case game(Int)
    case profile
}

private struct JoinGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let join: (Int, String?) async -> Bool
    @State private var gameNumber: String
    @State private var password = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    init(initialGameID: Int? = nil, join: @escaping (Int, String?) async -> Bool) {
        self.join = join
        _gameNumber = State(initialValue: initialGameID.map { String($0) } ?? "")
    }

    var body: some View {
        ZStack {
            HalftoneBackground()
            VStack(spacing: 18) {
                SectionHeadline(title: "Join a Game")
                Text("ENTER THE GAME NUMBER FROM YOUR HOST. ADD A PASSWORD FOR PRIVATE GAMES.")
                    .font(Newsprint.mono(11, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let errorMessage { ErrorBanner(message: errorMessage) }
                TextField("Game number", text: $gameNumber)
                    .keyboardType(.numberPad)
                    .newsprintField()
                SecureField("Password (if required)", text: $password)
                    .textInputAutocapitalization(.never)
                    .newsprintField()
                Button(isJoining ? "JOINING…" : "JOIN GAME") {
                    Task { await performJoin() }
                }
                .buttonStyle(PixelButtonStyle(filled: true))
                .disabled(Int(gameNumber) == nil || isJoining)
                Button("CANCEL") { dismiss() }
                    .buttonStyle(PixelButtonStyle())
            }
            .padding(22)
            .frame(maxWidth: 600)
        }
    }

    private func performJoin() async {
        guard let gameID = Int(gameNumber) else { return }
        isJoining = true
        if await join(gameID, password.isEmpty ? nil : password) {
            dismiss()
        } else {
            errorMessage = "Could not join. Check the game number and password."
        }
        isJoining = false
    }
}

private struct GameCard: View {
    let game: GameSummary
    let isMine: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BoxHeader(title: header)
            VStack(alignment: .leading, spacing: 8) {
                row("STATUS", game.status.uppercased())
                row("PLAYERS", "\(game.playerCount) / \(game.maxPlayers)")
                if game.phase == .waiting {
                    row("WAITING FOR", "\(game.waitingFor) MORE")
                } else if game.phase != .completed {
                    row("ROUND", "\(game.currentRound) / \(game.totalRounds)")
                }
                if game.isPrivate { row("TYPE", "PRIVATE ■") }

                Button(isMine ? (game.phase == .completed ? "VIEW RESULTS" : "GO TO GAME") : "JOIN GAME") {
                    action()
                }
                .buttonStyle(PixelButtonStyle(compact: true))
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(game.phase == .completed ? Newsprint.gray : Newsprint.paper)
        .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
    }

    private var header: String {
        var value = "GAME #\(game.id)"
        if game.phase == .completed { value += " ★ COMPLETED" }
        else if isMine { value += " ★ YOUR GAME" }
        return value
    }

    private func row(_ label: String, _ value: String) -> some View {
        (Text("\(label): ").bold() + Text(value))
            .font(Newsprint.mono(13))
    }
}

private struct CreateGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isCreating: Bool
    let create: (String?) async -> Bool
    @State private var isPrivate = false
    @State private var password = ""

    var body: some View {
        ZStack {
            HalftoneBackground()
            ScrollView {
                VStack(spacing: 20) {
                    SectionHeadline(title: "Create New Game")

                    VStack(alignment: .leading, spacing: 12) {
                        BoxHeader(title: "► How to Play")
                        Text("Five rounds. Two hidden AI players. Two final votes. Score for correct guesses and for fooling your friends.")
                            .font(Newsprint.mono(14))
                            .padding([.horizontal, .bottom], 16)
                    }
                    .newsprintCard(padding: 0)

                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("■ MAKE GAME PRIVATE", isOn: $isPrivate)
                            .font(Newsprint.mono(14, weight: .bold))
                            .tint(Newsprint.ink)
                        if isPrivate {
                            SecureField("Game password", text: $password)
                                .textInputAutocapitalization(.never)
                                .newsprintField()
                            Text("PLAYERS WILL NEED THIS PASSWORD TO JOIN.")
                                .font(Newsprint.mono(10))
                        }
                    }
                    .newsprintCard()
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionFooter
        }
    }

    private var actionFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 4)

            HStack(spacing: 12) {
                Button("CANCEL") { dismiss() }
                    .buttonStyle(PixelButtonStyle())

                Button(isCreating ? "CREATING…" : "CREATE GAME") {
                    Task { _ = await create(isPrivate ? password : nil) }
                }
                .buttonStyle(PixelButtonStyle(filled: true))
                .disabled(createDisabled)
                .opacity(createDisabled ? 0.5 : 1)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(Newsprint.paper.ignoresSafeArea(edges: .bottom))
    }

    private var createDisabled: Bool {
        isCreating || (isPrivate && password.isEmpty)
    }
}
