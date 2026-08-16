import SwiftUI

enum GoogleSignInButtonAppearance {
    static let label = "Continue with Google"
    static let height: CGFloat = 50
    static let cornerRadius: CGFloat = 6
    static let logoViewportSize: CGFloat = 30
    static let logoScale: CGFloat = 1.7
    static let borderWidth: CGFloat = 0.5
}

struct GoogleSignInButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                GoogleSignInLogo()

                Text(GoogleSignInButtonAppearance.label)
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(.black)
            .frame(
                maxWidth: .infinity,
                minHeight: GoogleSignInButtonAppearance.height,
                alignment: .center
            )
            .contentShape(
                RoundedRectangle(cornerRadius: GoogleSignInButtonAppearance.cornerRadius)
            )
        }
        .buttonStyle(.plain)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: GoogleSignInButtonAppearance.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: GoogleSignInButtonAppearance.cornerRadius)
                .stroke(.black.opacity(0.65), lineWidth: GoogleSignInButtonAppearance.borderWidth)
        }
        .disabled(isLoading)
        .accessibilityLabel(GoogleSignInButtonAppearance.label)
    }
}

private struct GoogleSignInLogo: View {
    var body: some View {
        Image("GoogleSignInLogo")
            .resizable()
            .scaledToFit()
            .frame(
                width: GoogleSignInButtonAppearance.logoViewportSize,
                height: GoogleSignInButtonAppearance.logoViewportSize
            )
            .scaleEffect(GoogleSignInButtonAppearance.logoScale)
            .frame(
                width: GoogleSignInButtonAppearance.logoViewportSize,
                height: GoogleSignInButtonAppearance.logoViewportSize
            )
            .clipped()
    }
}
