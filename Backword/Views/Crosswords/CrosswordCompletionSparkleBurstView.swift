import SwiftUI

struct CrosswordCompletionSparkleBurstView: View {
    let isActive: Bool

    private let particleCount = 10

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(AppFont.body(AppLayout.completionSparkleSize))
                    .foregroundColor(index.isMultiple(of: 3) ? .appCorrect : .appAccent)
                    .scaleEffect(isActive ? 1 : 0.15)
                    .opacity(isActive ? 0.9 : 0)
                    .offset(particleOffset(for: index))
                    .rotationEffect(.degrees(isActive ? Double(index * 28) : 0))
                    .animation(
                        .easeOut(duration: 0.55).delay(Double(index % 3) * 0.025),
                        value: isActive
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func particleOffset(for index: Int) -> CGSize {
        let angle = (CGFloat(index) / CGFloat(particleCount)) * CGFloat.pi * 2
        let distance: CGFloat = isActive ? 158 : 92
        return CGSize(
            width: cos(angle) * distance,
            height: sin(angle) * distance
        )
    }
}
