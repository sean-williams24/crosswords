import Testing
@testable import Backword

@MainActor
@Suite("Profile scoring guide")
struct ScoringRuleViewTests {
    @Test("Scoring guides accept a text heading without an icon")
    func textHeading() {
        let guide = ScoringRuleView(title: "Scoring", rows: [("Solved", "5 pts")])

        #expect(guide.title == "Scoring")
        #expect(guide.rows.count == 1)
        #expect(guide.rows[0].0 == "Solved")
        #expect(guide.rows[0].1 == "5 pts")
    }

    @Test("Anagram explanation matches the web scoring guide")
    func anagramExplanation() {
        let guide = ScoringRuleView.anagram()

        #expect(guide.title == "Anagram")
        #expect(guide.rows.map(\.0) == [
            "Under 30 seconds",
            "Under 60 seconds",
            "Under 120 seconds",
            "Under 180 seconds",
            "180 seconds or more",
            "Give up or missed",
        ])
        #expect(guide.rows.map(\.1) == ["5 pts", "4 pts", "3 pts", "2 pts", "1 pt", "0 pts"])
    }

    @Test("Anagram points agree with gameplay at each time boundary",
          arguments: [(0, 0), (29, 0), (30, 1), (59, 1), (60, 2),
                      (119, 2), (120, 3), (179, 3), (180, 4), (300, 4)])
    func anagramScoringBoundaries(seconds: Int, rowIndex: Int) {
        let points = AnagramProgress.points(for: seconds)
        let suffix = points == 1 ? "pt" : "pts"
        #expect(ScoringRuleView.anagram().rows[rowIndex].1 == "\(points) \(suffix)")
    }
}
