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

struct RatingBarLabelLayout: Layout {
    let fraction: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let label = subviews.first else { return .zero }
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let labelSize = label.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width ?? labelSize.width, height: labelSize.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let label = subviews.first else { return }
        let labelProposal = ProposedViewSize(width: bounds.width, height: nil)
        let labelWidth = label.sizeThatFits(labelProposal).width
        let offset = Self.leadingOffset(barWidth: bounds.width, fraction: fraction, labelWidth: labelWidth)
        label.place(at: CGPoint(x: bounds.minX + offset, y: bounds.minY), anchor: .topLeading, proposal: labelProposal)
    }

    static func leadingOffset(barWidth: CGFloat, fraction: Double, labelWidth: CGFloat) -> CGFloat {
        let dotX = barWidth * CGFloat(fraction)
        let ideal = dotX - labelWidth / 2
        if labelWidth > barWidth {
            return barWidth - labelWidth
        }
        return max(0, min(ideal, barWidth - labelWidth))
    }
}
