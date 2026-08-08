import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    private var canSubmit: Bool {
        email.contains("@") && !password.isEmpty && !isWorking
    }

    var body: some View {
        ZStack {
            HalftoneBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Masthead()

                    VStack(spacing: 18) {
                        SectionHeadline(title: "Sign In")
                        Text("Enter your email and password. If you're new, your account will be created automatically.")
                            .font(Newsprint.mono(13))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let error = session.errorMessage {
                            ErrorBanner(message: error)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text("EMAIL ADDRESS").font(Newsprint.mono(12, weight: .bold))
                            TextField("you@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .newsprintField()
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text("PASSWORD").font(Newsprint.mono(12, weight: .bold))
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .newsprintField()
                        }

                        Button(isWorking ? "SIGNING IN…" : "► SIGN IN / CREATE ACCOUNT") {
                            Task {
                                isWorking = true
                                _ = await session.signIn(email: email, password: password)
                                isWorking = false
                            }
                        }
                        .buttonStyle(PixelButtonStyle(filled: true))
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.45)

                        Link("FORGOT YOUR PASSWORD?", destination: URL(string: "https://turing.justinpaulson.com/passwords/new")!)
                            .font(Newsprint.mono(11, weight: .bold))
                            .underline()
                    }
                    .newsprintCard(padding: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        BoxHeader(title: "► How to Play")
                        rule("1", "Answer five creative questions")
                        rule("2", "Study every player's answers")
                        rule("3", "Find the two hidden AI players")
                        rule("4", "Score for detection and deception")
                    }
                    .newsprintCard(padding: 0)
                }
                .frame(maxWidth: 600)
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func rule(_ number: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(Newsprint.mono(17, weight: .black))
                .foregroundStyle(Newsprint.paper)
                .frame(width: 38, height: 38)
                .background(Newsprint.ink)
            Text(text).font(Newsprint.mono(14, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 12)
    }
}
