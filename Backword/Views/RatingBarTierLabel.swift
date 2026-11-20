import SwiftUI

struct RatingBarTierLabel: View {
    let tier: RatingTier

    var body: some View {
        HStack(spacing: 4) {
            if tier == .virtuoso {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tier.gradient)
            }
            Text(tier.displayName.uppercased())
                .font(AppFont.clueLabel(10))
                .foregroundStyle(tier.color)
                .tracking(1.5)
        }
    }
}
