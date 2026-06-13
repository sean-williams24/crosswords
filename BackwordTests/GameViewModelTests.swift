import Foundation
import Testing
@testable import Backword

@Suite("GameViewModel Tests")
@MainActor
struct GameViewModelTests {

    @Test("Completed crossword cells cannot be overwritten when correct highlighting is enabled")
    func completedCellsCannotBeOverwrittenWhenHighlightingEnabled() async throws {
        let originalHighlightSetting = AppSettings.shared.crosswordCorrectHighlight
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer {
            UserProgress.delete(puzzleId: puzzle.id)
            AppSettings.shared.crosswordCorrectHighlight = originalHighlightSetting
        }

        AppSettings.shared.crosswordCorrectHighlight = true
        let vm = GameViewModel(puzzle: puzzle)

        vm.enterLetter("A")
        vm.enterLetter("B")
        vm.selectCell(row: 0, col: 0)
        vm.enterLetter("Z")

        #expect(vm.progress.entries[0][0] == "A")
        #expect(vm.selectedRow == 0)
        #expect(vm.selectedCol == 0)
    }

    @Test("Completed crossword cells can be overwritten when correct highlighting is disabled")
    func completedCellsCanBeOverwrittenWhenHighlightingDisabled() async throws {
        let originalHighlightSetting = AppSettings.shared.crosswordCorrectHighlight
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer {
            UserProgress.delete(puzzleId: puzzle.id)
            AppSettings.shared.crosswordCorrectHighlight = originalHighlightSetting
        }

        AppSettings.shared.crosswordCorrectHighlight = false
        let vm = GameViewModel(puzzle: puzzle)

        vm.enterLetter("A")
        vm.enterLetter("B")
        vm.selectCell(row: 0, col: 0)
        vm.enterLetter("Z")

        #expect(vm.progress.entries[0][0] == "Z")
    }

    private func makePuzzle() -> Puzzle {
        let clue = Clue(
            id: 0,
            direction: .across,
            number: 1,
            text: "Two-letter test answer",
            hint: "First two letters",
            answer: "AB",
            startRow: 0,
            startCol: 0,
            length: 2
        )

        return Puzzle(
            id: "game-view-model-tests-\(UUID().uuidString)",
            puzzleNumber: 1,
            date: "2026-06-13",
            size: 2,
            cells: [
                [
                    CellData(letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: nil),
                    CellData(letter: "B", clueNumber: nil, acrossClueId: 0, downClueId: nil),
                ],
                [
                    CellData(letter: nil, clueNumber: nil, acrossClueId: nil, downClueId: nil),
                    CellData(letter: nil, clueNumber: nil, acrossClueId: nil, downClueId: nil),
                ],
            ],
            clues: [clue]
        )
    }
}
