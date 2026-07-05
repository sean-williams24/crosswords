import SwiftUI

struct AdExplainerView: View {
    @Binding var doNotShowAgain: Bool
    let gameName: String
    let close: () -> Void
    let play: () -> Void

    var body: some View {
        ZStack {
            AppBackgroundGradient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.appTextSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 18)

                Spacer(minLength: 20)

                VStack(spacing: 22) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("A quick note before you play...")
                            .font(AppFont.header(18))
                            .foregroundColor(.appTextHeading)
                            .multilineTextAlignment(.center)

                        Text("On the free version of Backword, we may show a full-screen advert before the \(gameName). The advert usually has a short progress bar or timer, and the close button appears when it finishes.")
                            .font(AppFont.body(15))
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("We only show one advert per day for each game.")
                            .font(AppFont.body(15))
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: play) {
                        Text("Let's play")
                            .font(AppFont.header(18))
                            .foregroundColor(.appBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
                    }

                    Toggle(isOn: $doNotShowAgain) {
                        Text("I get it, don't show this again")
                            .font(AppFont.body(15))
                            .foregroundColor(.appTextPrimary)
                    }
                    .tint(.appAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .frame(maxWidth: 520)

                Spacer(minLength: 30)
            }
        }
    }
}

#Preview {
    AdExplainerView(
        doNotShowAgain: .constant(false),
        gameName: "Crossword",
        close: {},
        play: {}
    )
}
