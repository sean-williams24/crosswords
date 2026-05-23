//
//  ScoringRuleView.swift
//  Backword
//
//  Created by Sean Williams on 21/05/2026.
//

import SwiftUI

struct ScoringRuleView: View {
    @ScaledMetric private var spacing: CGFloat = 8
    let icon: String
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: spacing) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.appAccent)
                    .frame(width: 20)
                Text(title)
                    .font(AppFont.clueLabel(13))
                    .foregroundColor(.appTextPrimary)
            }
            VStack(spacing: 4) {
                ForEach(rows, id: \.0) { label, pts in
                    HStack {
                        Text(label)
                            .font(AppFont.caption())
                            .foregroundColor(.appTextSecondary)
                        Spacer()
                        Text(pts)
                            .font(AppFont.clueLabel(11))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.leading, 28)
                }
            }
        }
    }

    static func backword() -> some View {
        ScoringRuleView(
            icon: "backward.circle",
            title: "Backword",
            rows: [
                ("Win in 1 guess", "5 pts"),
                ("Win in 2 guesses", "4 pts"),
                ("Win in 3 guesses", "3 pts"),
                ("Win in 4 guesses", "2 pts"),
                ("Win in 5 guesses", "1 pt"),
                ("Loss or missed", "0 pts"),
            ]
        )
    }

    static func crossword() -> some View {
        ScoringRuleView(
            icon: "square.grid.3x3.fill",
            title: "Daily & Weekly Crossword",
            rows: [
                ("100% complete", "5 pts"),
                ("75–99% complete", "4 pts"),
                ("50–74% complete", "3 pts"),
                ("25–49% complete", "2 pts"),
                ("1–24% complete", "1 pt"),
                ("Not started", "0 pts"),
            ]
        )
    }
}

#Preview {
    ScoringRuleView(icon: "backward.circle", title: "Win in 1 guess", rows: [("", "")])
}
