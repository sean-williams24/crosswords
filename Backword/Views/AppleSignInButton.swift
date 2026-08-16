import AuthenticationServices
import SwiftUI
import UIKit

/// A native Apple-branded button whose authorization controller is owned by
/// the app. Unlike SwiftUI's wrapper, cancelling the system flow cannot leave
/// the button rendering an in-progress indicator.
struct AppleSignInButton: UIViewRepresentable {
    let isLoading: Bool
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.beginAuthorization), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {
        button.isEnabled = !isLoading
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        private let onCompletion: (Result<ASAuthorization, Error>) -> Void
        private var activeController: ASAuthorizationController?
        private weak var presentationAnchor: ASPresentationAnchor?

        init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        @objc func beginAuthorization(_ sender: ASAuthorizationAppleIDButton) {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            AppleSignInRequestConfiguration.configure(request)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            presentationAnchor = sender.window
            activeController = controller
            controller.performRequests()
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            activeController = nil
            onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            activeController = nil
            onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            presentationAnchor ?? ASPresentationAnchor()
        }
    }
}

enum AppleSignInRequestConfiguration {
    static func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
}
