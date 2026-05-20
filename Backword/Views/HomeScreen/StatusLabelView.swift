//  StatusLabelView.swift

import SwiftUI

struct StatusLabelView: View {
    let status: PuzzleStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 11))
            Text(status.label)
                .font(AppFont.clueLabel(11))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.backgroundColor)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusLabelView(status: .notStarted)
        StatusLabelView(status: .inProgress)
        StatusLabelView(status: .completedOnTime)
        StatusLabelView(status: .completedLate)
    }
}
