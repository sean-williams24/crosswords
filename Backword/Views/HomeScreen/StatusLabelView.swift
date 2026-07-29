//  StatusLabelView.swift

import SwiftUI

struct StatusLabelView: View {
    let status: PuzzleStatus
    var textStyle: StatusLabelTextStyle = .statusColor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
                .foregroundColor(status.color)
            Text(status.label)
                .font(AppFont.clueLabel(11))
                .foregroundColor(textStyle.color(for: status))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.backgroundColor)
        .cornerRadius(12)
    }
}

enum StatusLabelTextStyle: Equatable {
    case statusColor
    case primary

    func color(for status: PuzzleStatus) -> Color {
        switch self {
        case .statusColor:
            return status.color
        case .primary:
            return .appTextPrimary
        }
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
