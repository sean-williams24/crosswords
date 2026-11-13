//
//  ScoringRuleView.swift
//  Backword
//
//  Created by Sean Williams on 21/05/2026.
//

import SwiftUI

struct ScoringRuleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.clueLabel(13))
                .foregroundColor(.appTextPrimary)
            VStack(spacing: 4) {
                ForEach(rows, id: \.0) { label, pts in
                    scoreRow(label: label, points: pts)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func scoreRow(label: String, points: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                scoreLabel(label)
                HStack {
                    Spacer()
                    scorePoints(points)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                scoreLabel(label)
                Spacer()
                scorePoints(points)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scoreLabel(_ label: String) -> some View {
        Text(label)
            .font(AppFont.caption())
            .foregroundColor(.appTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func scorePoints(_ points: String) -> some View {
        Text(points)
            .font(AppFont.clueLabel(11))
            .foregroundColor(Self.pointsColor(points))
            .fixedSize(horizontal: false, vertical: true)
    }

    static func pointsColor(_ points: String) -> Color {
        points == "0 pts" ? .appTextPrimary : .appAccent
    }

    static func backword(title: String = "Backword") -> ScoringRuleView {
        ScoringRuleView(
            title: title,
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

    static func anagram() -> ScoringRuleView {
        ScoringRuleView(
            title: "Anagram & Midword",
            rows: [
                ("Under 30 seconds", "5 pts"),
                ("Under 60 seconds", "4 pts"),
                ("Under 120 seconds", "3 pts"),
                ("Under 180 seconds", "2 pts"),
                ("180 seconds or more", "1 pt"),
                ("Give up or missed", "0 pts"),
            ]
        )
    }

    static func crossword() -> some View {
        ScoringRuleView(
            title: "Quick & Weekly Crossword",
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
    ScoringRuleView(
        title: "Win in 1 guess",
        rows: [("Win in 1 guess", "5 pts"),
               ("Win in 2 guesses", "4 pts"),
               ("Win in 3 guesses", "3 pts"),
               ("Win in 4 guesses", "2 pts"),
               ("Win in 5 guesses", "1 pt"),
               ("Loss or missed", "0 pts")]
    )
}
