import SwiftUI

@main
struct TuringTwistApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.light)
                .task { await session.restoreSession() }
        }
    }
}
