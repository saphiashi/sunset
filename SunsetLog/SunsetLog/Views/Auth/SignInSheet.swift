import SwiftUI
import AuthenticationServices

struct SignInSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keep the light")
                            .font(Typeface.italic(34))
                        Text(intro)
                            .font(Typeface.body(16))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !session.auth.isConfigured {
                        SoftBanner(text: "This build has placeholder Supabase keys. Add SUPABASE_URL and SUPABASE_ANON_KEY in Secrets.xcconfig — the journal still works on this phone.")
                    } else if session.auth.isSignedIn {
                        signedInBlock
                    } else {
                        appleBlock
                        magicBlock
                    }

                    if let error = session.auth.lastError, !error.isEmpty {
                        Text(error)
                            .font(Typeface.caption(13))
                            .foregroundStyle(.red)
                    }
                    if let status = session.auth.statusMessage {
                        Text(status)
                            .font(Typeface.caption(13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
            }
            .duskBackdrop()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var intro: String {
        if session.auth.isSignedIn {
            return "Evenings you log now land in your account. Friends you follow share their public skies. This phone keeps a copy if you’re offline."
        }
        return "The journal on this phone is yours either way. Sign in to sync evenings, photos, and the people you follow."
    }

    private var signedInBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let profile = session.auth.profile {
                HStack(spacing: 12) {
                    PersonMark(name: profile.displayName, hue: 0.08, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(Typeface.display(24))
                        Text("@\(profile.handle)")
                            .font(Typeface.caption(13))
                            .foregroundStyle(.secondary)
                        if let email = profile.email {
                            Text(email)
                                .font(Typeface.caption(12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            Text(session.cloud.lastStatus)
                .font(Typeface.caption(13))
                .foregroundStyle(.secondary)
            EmberButton(title: "Sign out", fill: false) {
                Task {
                    await session.auth.signOut()
                    dismiss()
                }
            }
        }
    }

    private var appleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = AuthNonce.random()
                session.auth.pendingNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AuthNonce.sha256(nonce)
            } onCompletion: { result in
                Task {
                    await session.auth.handleApple(result)
                    if session.auth.isSignedIn {
                        dismiss()
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(Capsule())
            .disabled(!session.auth.isConfigured)

            Text("Preferred. Requires the Sign in with Apple capability and the Apple provider in Supabase.")
                .font(Typeface.caption(12))
                .foregroundStyle(.secondary)
        }
    }

    private var magicBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or a link to your email")
                .font(Typeface.body(15, weight: .semibold))
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            EmberButton(title: sent ? "Link sent" : "Send a sign-in link", fill: true) {
                Task {
                    await session.auth.sendMagicLink(email: email)
                    sent = session.auth.lastError == nil
                }
            }
            .disabled(!session.auth.isConfigured || email.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
