import GoogleSignIn
import UIKit

enum GoogleNativeSignInError: LocalizedError, Equatable {
    case unavailable
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Google Sign-In could not be opened. Please try again."
        case .missingIDToken:
            return "Google Sign-In did not return an identity token. Please try again."
        }
    }
}

/// Presents Google's native account picker and returns the ID token that
/// Supabase exchanges for the app's authenticated session.
@MainActor
final class GoogleNativeSignInService {
    static let shared = GoogleNativeSignInService()

    private init() {}

    func signIn() async throws -> String {
        guard let presentingViewController = presentingViewController else {
            throw GoogleNativeSignInError.unavailable
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: Secrets.googleIOSClientID,
            serverClientID: Secrets.googleWebClientID
        )

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let idToken = result?.user.idToken?.tokenString else {
                    continuation.resume(throwing: GoogleNativeSignInError.missingIDToken)
                    return
                }

                continuation.resume(returning: idToken)
            }
        }
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    private var presentingViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }

        return visibleViewController(from: rootViewController)
    }

    private func visibleViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return visibleViewController(from: presentedViewController)
        }
        if let navigationController = viewController as? UINavigationController,
           let visibleController = navigationController.visibleViewController {
            return visibleViewController(from: visibleController)
        }
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return visibleViewController(from: selectedViewController)
        }
        return viewController
    }
}
