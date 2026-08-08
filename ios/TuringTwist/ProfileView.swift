import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var displayName = ""
    @State private var emailAddress = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var isSaving = false
    @State private var savedMessage: String?

    var body: some View {
        PageContainer {
            VStack(spacing: 18) {
                HStack {
                    NewsprintBackButton { dismiss() }
                    Spacer()
                }

                Masthead(compact: true)
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeadline(title: "Edit Profile")

                    if let error = session.errorMessage { ErrorBanner(message: error) }
                    if let savedMessage {
                        Text("ℹ \(savedMessage)")
                            .font(Newsprint.mono(13, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(13)
                            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 3))
                    }

                    field("DISPLAY NAME", hint: "This is how other players see you") {
                        TextField("Display name", text: $displayName).newsprintField()
                    }
                    field("EMAIL ADDRESS", hint: "Used for signing in") {
                        TextField("you@example.com", text: $emailAddress)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .newsprintField()
                    }

                    Rectangle().frame(height: 4)
                    Text("► LEAVE PASSWORD FIELDS BLANK TO KEEP YOUR CURRENT PASSWORD")
                        .font(Newsprint.mono(10, weight: .bold))

                    field("NEW PASSWORD", hint: nil) {
                        SecureField("Optional", text: $password)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .newsprintField()
                    }
                    field("CONFIRM NEW PASSWORD", hint: nil) {
                        SecureField("Confirm new password", text: $passwordConfirmation)
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .newsprintField()
                    }

                    Button(isSaving ? "SAVING…" : "SAVE CHANGES") {
                        Task { await save() }
                    }
                    .buttonStyle(PixelButtonStyle(filled: true))
                    .disabled(isSaving || displayName.isEmpty || emailAddress.isEmpty)
                }
                .newsprintCard(padding: 22)

                VStack(spacing: 14) {
                    BoxHeader(title: "Account Actions")
                    Button("SIGN OUT") { Task { await session.signOut() } }
                        .buttonStyle(PixelButtonStyle())
                        .padding([.horizontal, .bottom], 16)
                }
                .newsprintCard(padding: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { populate() }
    }

    private func field<Content: View>(
        _ label: String,
        hint: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(Newsprint.mono(12, weight: .bold))
            content()
            if let hint {
                Text("► \(hint)").font(Newsprint.mono(9)).opacity(0.7)
            }
        }
    }

    private func populate() {
        guard let user = session.user else { return }
        displayName = user.displayName ?? ""
        emailAddress = user.emailAddress
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let didSave = await session.updateProfile(
            displayName: displayName,
            emailAddress: emailAddress,
            password: password.isEmpty ? nil : password,
            passwordConfirmation: password.isEmpty ? nil : passwordConfirmation
        )
        if didSave {
            password = ""
            passwordConfirmation = ""
            savedMessage = "Profile updated."
        }
    }
}
