//  StatusLabelView.swift

import SwiftUI

struct StatusLabelView: View {
    let status: PuzzleStatus
    var textStyle: StatusLabelTextStyle = .statusColor
    var backgroundStyle: StatusLabelBackgroundStyle = .status
    var borderStyle: HomeCardBadgeBorderStyle = .none

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            Text(status.label)
                .font(AppFont.clueLabel(11))
                .foregroundColor(textStyle.color(for: status))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background)
        .cornerRadius(12)
        .overlay(border)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if status.usesWhiteCheckmark {
            ZStack {
                Image(systemName: "circle.fill")
                    .foregroundColor(status.color)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
            }
            .font(.caption2)
        } else {
            Image(systemName: status.icon)
                .font(.caption2)
                .foregroundColor(status.color)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch backgroundStyle {
        case .status:
            status.backgroundColor
        case .inProgress:
            PuzzleStatus.inProgress.backgroundColor
        }
    }

    @ViewBuilder
    private var border: some View {
        switch borderStyle {
        case .none:
            EmptyView()
        case .white:
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.appSurface, lineWidth: 1)
                .environment(\.colorScheme, .light)
        }
    }
}

enum StatusLabelBackgroundStyle: Equatable {
    case status
    case inProgress
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
