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
            LillyBitGamesLaunch { _ in RootView() }
                .environmentObject(session)
                .environmentObject(deepLinks)
                .preferredColorScheme(.light)
                .task { await session.restoreSession() }
                .onOpenURL { deepLinks.handle($0) }
        }
    }
}

// Shared studio artwork and two-second timing match Hoot Loop's opening card.
private struct LillyBitGamesLaunch<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isReady = false
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        ZStack {
            // Keep link and notification handlers mounted while the card is visible.
            content(isReady)
                .opacity(isReady ? 1 : 0)
                .allowsHitTesting(isReady)
                .accessibilityHidden(!isReady)
            if !isReady {
                GeometryReader { geometry in
                    ZStack {
                        Color(red: 0.98, green: 0.97, blue: 0.95).ignoresSafeArea()
                        Image("LillyBitGames")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(360, min(geometry.size.width, geometry.size.height) * 0.72))
                            .accessibilityLabel("Lilly Bit Games")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .accessibilityIdentifier("studio.launch")
            }
        }
        .task(id: scenePhase) {
            guard !isReady, scenePhase == .active else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            isReady = true
        }
    }
}
