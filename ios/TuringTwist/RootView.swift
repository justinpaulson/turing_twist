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
                GamesView()
            }
        }
        .tint(Newsprint.ink)
    }
}
