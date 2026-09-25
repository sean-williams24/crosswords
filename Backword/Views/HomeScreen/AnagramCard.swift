import SwiftUI

struct AnagramCard: View {
    let puzzle: AnagramPuzzle
    let isReview: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isReview ? "ANAGRAM · REVIEW" : "ANAGRAM")
                        .font(AppFont.header(24))
                    Text(isReview ? "Try the sample puzzle" : "Daily puzzle #\(puzzle.puzzleNumber)")
                        .font(AppFont.body())
                }
                Spacer()
                Image(systemName: "square.grid.3x3.fill")
                    .font(AppFont.header(26))
            }
            .foregroundStyle(Color.anagramOnOrange)
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 128)
            .background(Color.anagramOrange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isReview ? "Play Anagram review puzzle" : "Play today's Anagram")
    }
}
