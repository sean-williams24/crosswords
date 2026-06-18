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

    @Test("Retyping the same locked crossword letter advances to the next cell")
    func retypingSameLockedLetterAdvancesWhenHighlightingEnabled() async throws {
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
        vm.enterLetter("A")

        #expect(vm.progress.entries[0][0] == "A")
        #expect(vm.selectedRow == 0)
        #expect(vm.selectedCol == 1)
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

    @Test("Rewarded hint grant consumes one hint for a new clue")
    func rewardedHintGrantConsumesOneHintForNewClue() async throws {
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(puzzle: puzzle)

        let didGrantHint = vm.grantRewardedHint()

        #expect(didGrantHint)
        #expect(vm.adBonusHints == 1)
        #expect(vm.progress.hintsUsed == 1)
        #expect(vm.progress.hintedClueIds.contains(0))
        #expect(vm.showHint)
    }

    @Test("Rewarded hint grant is idempotent for an already hinted clue")
    func rewardedHintGrantIsIdempotentForAlreadyHintedClue() async throws {
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(puzzle: puzzle)

        #expect(vm.grantRewardedHint())
        #expect(vm.grantRewardedHint())

        #expect(vm.adBonusHints == 1)
        #expect(vm.progress.hintsUsed == 1)
        #expect(vm.progress.hintedClueIds == [0])
        #expect(vm.showHint)
    }

    @Test("Rewarded hint grant does not consume a hint for an already answered clue")
    func rewardedHintGrantDoesNotConsumeHintForAlreadyAnsweredClue() async throws {
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(puzzle: puzzle)
        vm.enterLetter("A")
        vm.enterLetter("B")

        let didGrantHint = vm.grantRewardedHint()

        #expect(!didGrantHint)
        #expect(vm.adBonusHints == 0)
        #expect(vm.progress.hintsUsed == 0)
        #expect(vm.progress.hintedClueIds.isEmpty)
        #expect(!vm.showHint)
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
