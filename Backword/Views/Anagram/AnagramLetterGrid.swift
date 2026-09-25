import SwiftUI

struct AnagramLetterGrid: View {
    let puzzle: AnagramPuzzle
    let progress: AnagramProgress
    let place: (Int) -> Void

    private var answerColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: AppLayout.anagramAnswerTileSpacing),
            count: puzzle.length
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR ANSWER")
                    .font(AppFont.clueLabel())
                    .foregroundStyle(Color.anagramOrange)
                LazyVGrid(columns: answerColumns, spacing: AppLayout.anagramAnswerTileSpacing) {
                    ForEach(0..<puzzle.length, id: \.self) { cell in
                        answerCell(cell)
                    }
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("TAP LETTERS IN ORDER")
                    .font(AppFont.clueLabel())
                    .foregroundStyle(Color.anagramOrange)
                AnagramTrayLayout(spacing: AppLayout.anagramTrayTileSpacing) {
                    ForEach(progress.trayOrder, id: \.self) { tile in
                        trayCell(tile)
                    }
                }
            }
        }
    }

    private func answerCell(_ index: Int) -> some View {
        let tile = progress.placedTileIDs[index]
        let locked = index == progress.lockedCellIndex
        return ZStack {
            Rectangle()
                .fill(tile == nil ? Color.anagramSurface : Color.anagramOrange)
            Rectangle()
                .strokeBorder(Color.anagramOrange, lineWidth: locked ? 3 : 1)
            if let tile {
                Text(String(Array(puzzle.initialScramble)[tile]))
                    .font(AppFont.header(24))
                    .foregroundStyle(Color.anagramOnOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer cell \(index + 1), \(tile.map { String(Array(puzzle.initialScramble)[$0]) } ?? "empty")\(locked ? ", hint locked" : "")")
    }

    private func trayCell(_ tile: Int) -> some View {
        let available = progress.availableTileIDs.contains(tile)
        return Button { place(tile) } label: {
            ZStack {
                Rectangle()
                    .fill(available ? Color.anagramOrange : Color.anagramSurface)
                if available {
                    Text(String(Array(puzzle.initialScramble)[tile]))
                        .font(AppFont.header(24))
                        .foregroundStyle(Color.anagramOnOrange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!available || progress.isComplete)
        .accessibilityLabel(available ? "Place \(Array(puzzle.initialScramble)[tile]), tile \(tile + 1)" : "Tile \(tile + 1), empty")
    }
}
