import SwiftUI
import UIKit

struct HomeDailyChallengeCelebration: View {
    static let message = "Your daily Intervls, complete."

    var body: some View {
        Label(Self.message, systemImage: "sparkles")
            .font(AppFont.body())
            .foregroundStyle(Color.appTextPrimary)
            .padding(AppLayout.homeDailyCelebrationPadding)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .strokeBorder(Color.solvedGold.opacity(0.4), lineWidth: AppLayout.homeDailyCardBorderWidth)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.message)
            .onAppear {
                UIAccessibility.post(notification: .announcement, argument: Self.message)
            }
            .allowsHitTesting(false)
    }
}
