//  StatusLabelView.swift

import SwiftUI

struct StatusLabelView: View {
    let status: PuzzleStatus

    var body: some View {
        Text(status.label)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .font(AppFont.statNumber(10))
            .foregroundStyle(status.color)
            .background(content: {
                RoundedRectangle(cornerRadius: 10)
                    .shadow(radius: 2)
            })
    }
}

#Preview {
    StatusLabelView(status: .new)
}
