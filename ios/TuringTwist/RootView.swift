import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.isRestoring {
                ZStack {
                    HalftoneBackground()
                    VStack(spacing: 24) {
                        Masthead()
                        LoadingView()
                    }
                    .padding()
                    .frame(maxWidth: 600)
                }
            } else if session.token == nil {
                SignInView()
            } else {
                MainShellView()
            }
        }
        .tint(Newsprint.ink)
    }
}

private struct MainShellView: View {
    var body: some View {
        TabView {
            GamesView()
                .tabItem { Label("Games", systemImage: "checkerboard.rectangle") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.square") }
        }
        .toolbarBackground(Newsprint.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
