import SwiftUI

struct BackwordLightbulbIcon: View {
    var body: some View {
        Image(systemName: "lightbulb")
            .font(AppFont.body(15))
            .foregroundColor(.solvedGold)
            .fixedSize()
            .accessibilityHidden(true)
    }
}
