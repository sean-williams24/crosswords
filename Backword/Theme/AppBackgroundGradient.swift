//  AppBackgroundGradient.swift

import SwiftUI

struct AppBackgroundGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .appBackground.opacity(0.7), location: 0),
                .init(color: .appBackground, location: 0.1),
                .init(color: .appCrosswordBackground, location: 0.25),
                .init(color: .appCrosswordBackground, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    AppBackgroundGradient()
}
