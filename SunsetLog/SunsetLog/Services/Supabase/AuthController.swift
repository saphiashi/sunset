import Foundation
import Observation
import AuthenticationServices
import Supabase

private struct DeleteAccountRequest: Encodable {
    var appleAuthorizationCode: String?

    enum CodingKeys: String, CodingKey {
        case appleAuthorizationCode = "apple_authorization_code"
    }
}

struct AuthProfile: Equatable, Sendable {
    var userID: UUID
    var email: String?
    var handle: String
    var displayName: String
}

@MainActor
@Observable
final class AuthController {
    private(set) var isConfigured: Bool
    private(set) var isSignedIn = false
    private(set) var profile: AuthProfile?
    private(set) var statusMessage: String?
    private(set) var lastError: String?
    /// Apple accounts re-authorize before deletion so the server can revoke the token.
    private(set) var signedInWithApple = false

    var pendingNonce: String?
    var onSessionChange: (() -> Void)?
    /// A different account signed in than the one whose data is on this phone.
    /// Runs before the first sync so the old journal never uploads to the new account.
    var onAccountSwitch: (() -> Void)?

    /// The account whose journal is on this phone. Persists through sign-out, so
    /// evenings logged while signed out sync only if that same account returns.
    static let journalOwnerKey = "journalOwnerID"

    /// Exposed to CloudSync / PhotoUploader. Nil when keys are placeholders.
    let client: SupabaseClient?

    convenience init() {
        self.init(client: AuthController.makeClient())
    }

    init(client: SupabaseClient?) {
        self.client = client
        self.isConfigured = client != nil
    }

    nonisolated static func makeClient() -> SupabaseClient? {
        guard SupabaseConfig.isConfigured, let url = SupabaseConfig.url else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
    }

    var userID: UUID? { profile?.userID }

    func restoreSession() async {
        guard let client else { return }
        do {
            let session = try await client.auth.session
            await apply(session: session)
        } catch {
            isSignedIn = false
            profile = nil
        }
        listenForAuthChanges()
    }

    func handleOpenURL(_ url: URL) async {
        guard let client else { return }
        do {
            let session = try await client.auth.session(from: url)
            await apply(session: session)
            statusMessage = "You’re signed in."
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            await signInWithApple(authorization)
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                lastError = nil
                return
            }
            lastError = error.localizedDescription
        }
    }

    func sendMagicLink(email: String) async {
        guard let client else {
            lastError = "Add your Supabase URL and anon key in Secrets.xcconfig."
            return
        }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@") else {
            lastError = "That doesn’t look like an email."
            return
        }
        do {
            try await client.auth.signInWithOTP(
                email: trimmed,
                redirectTo: URL(string: "sunsetlog://auth-callback")
            )
            statusMessage = "Check your mail for a sign-in link. Open it on this phone."
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        guard let client else { return }
        do {
            try await client.auth.signOut()
        } catch {
            lastError = error.localizedDescription
        }
        isSignedIn = false
        profile = nil
        statusMessage = "Signed out. The journal stays on this phone until a different account signs in."
        onSessionChange?()
    }

    func updateDisplayName(_ name: String) async {
        guard let client, let userID else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await client
                .from("profiles")
                .update(["display_name": trimmed])
                .eq("id", value: userID.uuidString.lowercased())
                .execute()
            if var profile {
                profile.displayName = trimmed
                self.profile = profile
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The `delete-account` Edge Function revokes the Apple token (given a fresh
    /// authorization code), deletes the auth user and everything they own, then their photos.
    func deleteAccount(appleAuthorizationCode: String?) async -> Bool {
        guard let client, isSignedIn else { return false }
        do {
            try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: DeleteAccountRequest(appleAuthorizationCode: appleAuthorizationCode)
                )
            )
        } catch {
            lastError = error.localizedDescription
            return false
        }
        try? await client.auth.signOut(scope: .local)
        isSignedIn = false
        signedInWithApple = false
        profile = nil
        statusMessage = "Account deleted."
        onSessionChange?()
        return true
    }

    private func signInWithApple(_ authorization: ASAuthorization) async {
        guard let client else {
            lastError = "Add your Supabase URL and anon key in Secrets.xcconfig."
            return
        }
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            lastError = "Apple didn’t return an identity token."
            return
        }
        guard let nonce = pendingNonce else {
            lastError = "Sign in with Apple is missing its nonce. Try again."
            return
        }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            await apply(session: session)
            let appleName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            if !appleName.trimmingCharacters(in: .whitespaces).isEmpty {
                await updateDisplayName(appleName)
            }
            lastError = nil
            statusMessage = "Signed in with Apple."
        } catch {
            lastError = error.localizedDescription
        }
    }

    private var didListen = false

    private func listenForAuthChanges() {
        guard let client, !didListen else { return }
        didListen = true
        Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                await self?.apply(session: session)
            }
        }
    }

    private func apply(session: Session?) async {
        let wasSignedIn = isSignedIn
        guard let session else {
            isSignedIn = false
            signedInWithApple = false
            profile = nil
            if wasSignedIn {
                onSessionChange?()
            }
            return
        }
        let userID = session.user.id
        let defaults = UserDefaults.standard
        if let owner = defaults.string(forKey: Self.journalOwnerKey), owner != userID.uuidString {
            onAccountSwitch?()
        }
        defaults.set(userID.uuidString, forKey: Self.journalOwnerKey)
        isSignedIn = true
        signedInWithApple = session.user.identities?.contains { $0.provider == "apple" } ?? false
        var handle = "you"
        var displayName = session.user.email?.split(separator: "@").first.map(String.init) ?? "You"
        if let client {
            if let row: ProfileRow = try? await client
                .from("profiles")
                .select()
                .eq("id", value: userID.uuidString.lowercased())
                .single()
                .execute()
                .value {
                handle = row.handle
                displayName = row.displayName
            }
        }
        profile = AuthProfile(
            userID: userID,
            email: session.user.email,
            handle: handle,
            displayName: displayName
        )
        onSessionChange?()
    }
}
