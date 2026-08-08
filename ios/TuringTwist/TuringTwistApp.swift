import SwiftUI

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published private(set) var pendingGameID: Int?
    @Published private(set) var revision = 0

    func handle(_ url: URL) {
        let path = url.pathComponents.filter { $0 != "/" }
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "turing.justinpaulson.com",
              path.count == 3,
              path[0] == "invite",
              path[1] == "games",
              let gameID = Int(path[2]),
              gameID > 0 else { return }

        pendingGameID = gameID
        revision &+= 1
    }

    func consumeGameID() -> Int? {
        defer { pendingGameID = nil }
        return pendingGameID
    }
}

@main
struct TuringTwistApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var deepLinks = DeepLinkRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(deepLinks)
                .preferredColorScheme(.light)
                .task { await session.restoreSession() }
                .onOpenURL { deepLinks.handle($0) }
        }
    }
}
