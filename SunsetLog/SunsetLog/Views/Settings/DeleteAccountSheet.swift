import SwiftUI
import SwiftData
import AuthenticationServices

struct DeleteAccountSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Delete your account?")
                    .font(Typeface.italic(30))
                Text("Your profile, sunsets, photos, collections, and follows are removed from the cloud and this phone. This can’t be undone.")
                    .font(Typeface.body(16))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if session.auth.signedInWithApple {
                    Text("Confirm with Apple so Sunset Log also stops using your Apple ID.")
                        .font(Typeface.caption(13))
                        .foregroundStyle(.secondary)
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = []
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .disabled(deleting)
                } else {
                    Button(role: .destructive) {
                        Task { await delete(appleCode: nil) }
                    } label: {
                        Text(deleting ? "Deleting…" : "Delete account and photos")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(deleting)
                }

                if deleting {
                    ProgressView()
                }
                if let error {
                    Text(error)
                        .font(Typeface.caption(13))
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .padding(22)
            .duskBackdrop()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(deleting)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(deleting)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let codeData = credential.authorizationCode,
                let code = String(data: codeData, encoding: .utf8)
            else {
                error = "Apple didn’t return an authorization code. Try again."
                return
            }
            Task { await delete(appleCode: code) }
        case .failure(let failure):
            if (failure as NSError).code != ASAuthorizationError.canceled.rawValue {
                error = failure.localizedDescription
            }
        }
    }

    private func delete(appleCode: String?) async {
        deleting = true
        error = nil
        defer { deleting = false }
        if await session.auth.deleteAccount(appleAuthorizationCode: appleCode) {
            SeedStore.reset(context)
            ImageStore.removeAll()
            dismiss()
        } else {
            error = session.auth.lastError ?? "Couldn’t delete the account. Try again."
        }
    }
}
