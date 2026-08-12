import AuthenticationServices
import SwiftUI

struct AccountSheet: View {
    @EnvironmentObject private var accountService: AccountService
    @Environment(\.dismiss) private var dismiss
    @State private var showDeletionConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if accountService.isSignedIn {
                        signedInContent
                    } else {
                        signedOutContent
                    }

                    if let errorMessage = accountService.errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundColor(.appGaveUp)
                    }
                }
                .padding(AppLayout.screenPadding)
            }
            .background(Color.appBackground)
            .navigationTitle(accountService.isSignedIn ? "Your Account" : "Save Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            .confirmationDialog(
                "Delete Backword account?",
                isPresented: $showDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        if await accountService.deleteAccount() {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This permanently deletes your cloud progress and account. It does not cancel your Apple subscription.")
            }
            .task { await accountService.refreshAccountData() }
        }
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Play as a guest whenever you like. An account lets you:")
                .font(AppFont.body(16))
                .foregroundColor(.appTextPrimary)

            benefits

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                guard case .success(let authorization) = result,
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let token = String(data: tokenData, encoding: .utf8) else { return }
                Task {
                    await accountService.signInWithApple(idToken: token, fullName: credential.fullName)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .disabled(accountService.isLoading)

            Button {
                Task { await accountService.signInWithGoogle() }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text(accountService.isLoading ? "Opening sign in…" : "Continue with Google")
                    Spacer()
                }
                .font(AppFont.body(16))
                .foregroundColor(.appTextPrimary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(accountService.isLoading)

            Text("If you use Apple’s Hide My Email, use Apple to sign in on every device.")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
        }
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(accountService.email ?? "Signed in")
                    .font(AppFont.body(17))
                    .foregroundColor(.appTextPrimary)
                Text(accountService.isSyncing ? "Syncing your games…" : "Progress and stats are synced")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))

            Label(
                accountService.isProUser ? "Pro is active for this account" : "No account-linked Pro subscription",
                systemImage: accountService.isProUser ? "checkmark.seal.fill" : "person.crop.circle"
            )
            .font(AppFont.body(15))
            .foregroundColor(accountService.isProUser ? .appAccent : .appTextSecondary)

            Button("Sync Now") { Task { await accountService.refreshAccountData() } }
                .font(AppFont.body(16))
                .foregroundColor(.appAccent)

            Button("Sign Out") { Task { await accountService.signOut() } }
                .font(AppFont.body(16))
                .foregroundColor(.appTextPrimary)

            Divider()

            Button("Delete Account", role: .destructive) {
                showDeletionConfirmation = true
            }
            .font(AppFont.body(16))
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("arrow.triangle.2.circlepath", "Continue a game on another device or the web.")
            benefit("chart.bar.fill", "Keep your stats, streaks, and score history safe.")
            benefit("crown.fill", "Keep your verified Pro access connected to Backword.")
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(AppFont.body(15))
            .foregroundColor(.appTextPrimary)
    }
}
