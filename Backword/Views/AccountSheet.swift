import AuthenticationServices
import SwiftUI

struct AccountSheet: View {
    @EnvironmentObject private var accountService: AccountService
    @Environment(\.dismiss) private var dismiss
    var onSuccessfulSignIn: () -> Void = {}

    var body: some View {
        NavigationStack {
            signedOutScreen
            .background(Color.appBackground)
            .navigationTitle("")
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
        }
    }

    private var signedOutScreen: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppLayout.screenPadding) {
                        signedOutHeader
                        signedOutInformation

                        Spacer()
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(0, geometry.size.height - (AppLayout.screenPadding * 2))
                    )
                    .padding(AppLayout.screenPadding)
                }
            }

            signInActions
                .padding(AppLayout.screenPadding)
        }
    }

    private var signedOutHeader: some View {
        VStack(spacing: AppLayout.screenPadding) {
            BackwordLogo(frame: 48)
                .accessibilityHidden(true)
            Text(AccountSheetGuestAccessPresentation.pageTitle)
                .font(AppFont.header(18))
                .foregroundColor(.appTextHeading)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var signedOutInformation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Play as a guest whenever you like, or create an account to:")
                .font(AppFont.body(16))
                .foregroundColor(.appTextPrimary)

            benefits

            Text("If you use Apple’s Hide My Email, use Apple to sign in on every device.")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)

            if let errorMessage = accountService.errorMessage {
                Text(errorMessage)
                    .font(AppFont.caption())
                    .foregroundColor(.appGaveUp)
            }
        }
    }

    private var signInActions: some View {
        VStack(spacing: 18) {
            AppleSignInButton(isLoading: accountService.isLoading) { result in
                guard case .success(let authorization) = result,
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let token = String(data: tokenData, encoding: .utf8) else { return }
                Task {
                    let didSignIn = await accountService.signInWithApple(
                        idToken: token,
                        fullName: credential.fullName
                    )
                    if didSignIn {
                        onSuccessfulSignIn()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)

            GoogleSignInButton(isLoading: accountService.isLoading) {
                Task {
                    if await accountService.signInWithGoogle() {
                        onSuccessfulSignIn()
                    }
                }
            }

            Button(AccountSheetGuestAccessPresentation.actionTitle) {
                dismiss()
            }
            .font(AppFont.body(16))
            .foregroundColor(.appTextPrimary)
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

enum AccountSheetGuestAccessPresentation {
    static let pageTitle = "Sign in or create an account"
    static let actionTitle = "Play as guest"
}

enum AccountPresentationDestination: Equatable {
    case signIn
    case ratingDetails

    static func destination(isSignedIn: Bool) -> Self {
        isSignedIn ? .ratingDetails : .signIn
    }
}

enum AccountEntitlementPresentation {
    static let linkedElsewhereExplanation =
        "This App Store subscription is linked to another Backword account, so it is not shared with this account or on the web."

    static func isAlreadyLinkedPurchaseError(_ message: String) -> Bool {
        message == "This purchase belongs to a different Backword account."
            || message == "This subscription is already linked to another Backword account."
    }
}
