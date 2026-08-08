import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var token: String?
    @Published private(set) var isRestoring = true
    @Published var errorMessage: String?

    init() {
        token = KeychainStore.loadToken()
    }

    func restoreSession() async {
        defer { isRestoring = false }
        guard let token else { return }

        do {
            user = try await APIClient.shared.profile(token: token).user
        } catch {
            KeychainStore.deleteToken()
            self.token = nil
            user = nil
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        do {
            let response = try await APIClient.shared.signIn(email: email, password: password)
            token = response.token
            user = response.user
            KeychainStore.save(token: response.token)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateProfile(
        displayName: String,
        emailAddress: String,
        password: String?,
        passwordConfirmation: String?
    ) async -> Bool {
        guard let token else { return false }
        do {
            let response = try await APIClient.shared.updateProfile(
                displayName: displayName,
                emailAddress: emailAddress,
                password: password,
                passwordConfirmation: passwordConfirmation,
                token: token
            )
            user = response.user
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        if let token {
            try? await APIClient.shared.signOut(token: token)
        }
        KeychainStore.deleteToken()
        token = nil
        user = nil
    }
}
