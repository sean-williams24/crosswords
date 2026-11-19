import SwiftUI

/// The same cell moves from the input row into its smaller history position.
struct MidwordAnimatedGuessCell: View {
    let letter: Character
    let size: CGFloat
    let guessIndex: Int
    let letterIndex: Int
    let namespace: Namespace.ID?

    var body: some View {
        if let namespace {
            cell.matchedGeometryEffect(id: "\(guessIndex)-\(letterIndex)", in: namespace)
                .transition(.identity)
        } else {
            cell
        }
    }

    private var cell: some View {
        BackwordLetterCell(
            letter: nil, inputLetter: letter, size: size,
            accentColor: .midwordAccent, surfaceColor: .midwordBackground,
            textColor: .midwordText, inactiveBorderColor: .midwordInactiveCellBorder
        )
    }
}
