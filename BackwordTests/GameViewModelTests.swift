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

    @Test("Pro users can use hints without rewarded banner after free hint limit")
    func proUsersCanUseHintsWithoutRewardedBannerAfterFreeHintLimit() {
        #expect(GameViewModel.canUseHintWithoutRewardedBanner(
            isProUser: true,
            activeClueIsHinted: false,
            hintedClueCount: 3,
            freeHintLimit: 0,
            adBonusHints: 0
        ))
    }

    @Test("Free users see rewarded banner after hint allowance is used")
    func freeUsersSeeRewardedBannerAfterHintAllowanceIsUsed() {
        #expect(!GameViewModel.canUseHintWithoutRewardedBanner(
            isProUser: false,
            activeClueIsHinted: false,
            hintedClueCount: 1,
            freeHintLimit: 1,
            adBonusHints: 0
        ))
    }

    @Test("Already hinted clue can be shown without rewarded banner")
    func alreadyHintedClueCanBeShownWithoutRewardedBanner() {
        #expect(GameViewModel.canUseHintWithoutRewardedBanner(
            isProUser: false,
            activeClueIsHinted: true,
            hintedClueCount: 1,
            freeHintLimit: 0,
            adBonusHints: 0
        ))
    }

    @Test("Give up fills answers, completes clues, and persists metadata")
    func giveUpFillsAnswersCompletesCluesAndPersistsMetadata() async throws {
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )

        vm.giveUp(displayScore: 3)

        #expect(vm.progress.entries[0][0] == "A")
        #expect(vm.progress.entries[0][1] == "B")
        #expect(vm.progress.completedClueIds == [0])
        #expect(vm.progress.completedAt != nil)
        #expect(vm.progress.gaveUpAt != nil)
        #expect(vm.progress.gaveUpScore == 3)
        #expect(vm.progress.gaveUpRevealedCells == ["0,0", "0,1"])
        #expect(vm.isComplete)

        let saved = try #require(UserProgress.load(puzzleId: puzzle.id))
        #expect(saved.gaveUpAt != nil)
        #expect(saved.gaveUpScore == 3)
        #expect(saved.gaveUpRevealedCells == ["0,0", "0,1"])
        #expect(saved.entries[0][0] == "A")
        #expect(saved.entries[0][1] == "B")
    }

    @Test("Give up marks only previously incomplete cells as revealed")
    func giveUpMarksOnlyPreviouslyIncompleteCellsAsRevealed() async throws {
        let puzzle = makeTwoAnswerPuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )

        vm.enterLetter("A")
        vm.enterLetter("B")
        vm.giveUp(displayScore: 3)

        #expect(!vm.isGaveUpRevealed(row: 0, col: 0))
        #expect(!vm.isGaveUpRevealed(row: 0, col: 1))
        #expect(vm.isGaveUpRevealed(row: 1, col: 0))
        #expect(vm.isGaveUpRevealed(row: 1, col: 1))
        #expect(vm.progress.gaveUpRevealedCells == ["1,0", "1,1"])
    }

    @Test("Give up locks entries against typing and deleting")
    func giveUpLocksEntriesAgainstTypingAndDeleting() async throws {
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )
        vm.giveUp(displayScore: 2)

        vm.selectCell(row: 0, col: 0)
        vm.enterLetter("Z")
        vm.deleteLetter()

        #expect(vm.progress.entries[0][0] == "A")
        #expect(vm.progress.entries[0][1] == "B")
    }

    @Test("Normal solve completes without give up metadata")
    func normalSolveCompletesWithoutGiveUpMetadata() async throws {
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(puzzle: puzzle)
        vm.enterLetter("A")
        vm.enterLetter("B")

        #expect(vm.isComplete)
        #expect(vm.progress.completedAt != nil)
        #expect(vm.progress.gaveUpAt == nil)
        #expect(vm.progress.gaveUpScore == nil)
    }

    @Test("Home-launched puzzle cannot give up")
    func homeLaunchedPuzzleCannotGiveUp() async throws {
        let puzzle = makePuzzle(date: "2026-06-17")
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(puzzle: puzzle)

        #expect(!vm.canGiveUp(isProUser: true, todayString: "2026-06-18"))
    }

    @Test("Archive daily for today cannot give up")
    func archiveDailyForTodayCannotGiveUp() async throws {
        let puzzle = makePuzzle(date: "2026-06-18")
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )

        #expect(!vm.canGiveUp(isProUser: true, todayString: "2026-06-18"))
    }

    @Test("Archive daily before today can give up for Pro")
    func archiveDailyBeforeTodayCanGiveUpForPro() async throws {
        let puzzle = makePuzzle(date: "2026-06-17")
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )

        #expect(vm.canGiveUp(isProUser: true, todayString: "2026-06-18"))
    }

    @Test("Current archive weekly cannot give up")
    func currentArchiveWeeklyCannotGiveUp() async throws {
        let puzzle = makePuzzle(id: "current-weekly", date: "2026-06-15")
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .weekly, currentWeeklyPuzzleId: "current-weekly")
        )

        #expect(!vm.canGiveUp(isProUser: true, todayString: "2026-06-18"))
    }

    @Test("Older archive weekly can give up for Pro")
    func olderArchiveWeeklyCanGiveUpForPro() async throws {
        let puzzle = makePuzzle(id: "older-weekly", date: "2026-06-08")
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .weekly, currentWeeklyPuzzleId: "current-weekly")
        )

        #expect(vm.canGiveUp(isProUser: true, todayString: "2026-06-18"))
    }

    @Test("Free archive users cannot give up")
    func freeArchiveUsersCannotGiveUp() async throws {
        let puzzle = makePuzzle(date: "2026-06-17")
        UserProgress.delete(puzzleId: puzzle.id)
        defer { UserProgress.delete(puzzleId: puzzle.id) }

        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )

        #expect(!vm.canGiveUp(isProUser: false, todayString: "2026-06-18"))
    }

    @Test("Home daily crossword shows onboarding before it has been seen")
    func homeDailyCrosswordShowsOnboardingBeforeSeen() async throws {
        let originalOnboardingSetting = AppSettings.shared.hasSeenDailyCrosswordOnboarding
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer {
            UserProgress.delete(puzzleId: puzzle.id)
            AppSettings.shared.hasSeenDailyCrosswordOnboarding = originalOnboardingSetting
        }

        AppSettings.shared.hasSeenDailyCrosswordOnboarding = false
        let vm = GameViewModel(puzzle: puzzle)

        #expect(vm.shouldShowDailyCrosswordOnboarding)
    }

    @Test("Home daily crossword does not show onboarding after it has been marked seen")
    func homeDailyCrosswordDoesNotShowOnboardingAfterSeen() async throws {
        let originalOnboardingSetting = AppSettings.shared.hasSeenDailyCrosswordOnboarding
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer {
            UserProgress.delete(puzzleId: puzzle.id)
            AppSettings.shared.hasSeenDailyCrosswordOnboarding = originalOnboardingSetting
        }

        AppSettings.shared.hasSeenDailyCrosswordOnboarding = false
        let vm = GameViewModel(puzzle: puzzle)

        vm.markDailyCrosswordOnboardingSeen()

        #expect(!vm.shouldShowDailyCrosswordOnboarding)
    }

    @Test("Home weekly crossword does not show daily onboarding")
    func homeWeeklyCrosswordDoesNotShowDailyOnboarding() async throws {
        let originalOnboardingSetting = AppSettings.shared.hasSeenDailyCrosswordOnboarding
        let puzzle = makePuzzle(size: 13)
        UserProgress.delete(puzzleId: puzzle.id)
        defer {
            UserProgress.delete(puzzleId: puzzle.id)
            AppSettings.shared.hasSeenDailyCrosswordOnboarding = originalOnboardingSetting
        }

        AppSettings.shared.hasSeenDailyCrosswordOnboarding = false
        let vm = GameViewModel(puzzle: puzzle)

        #expect(!vm.shouldShowDailyCrosswordOnboarding)
    }

    @Test("Archive daily crossword does not auto-show onboarding")
    func archiveDailyCrosswordDoesNotAutoShowOnboarding() async throws {
        let originalOnboardingSetting = AppSettings.shared.hasSeenDailyCrosswordOnboarding
        let puzzle = makePuzzle()
        UserProgress.delete(puzzleId: puzzle.id)
        defer {
            UserProgress.delete(puzzleId: puzzle.id)
            AppSettings.shared.hasSeenDailyCrosswordOnboarding = originalOnboardingSetting
        }

        AppSettings.shared.hasSeenDailyCrosswordOnboarding = false
        let vm = GameViewModel(
            puzzle: puzzle,
            launchContext: .archive(type: .daily, currentWeeklyPuzzleId: nil)
        )

        #expect(!vm.shouldShowDailyCrosswordOnboarding)
    }

    private func makePuzzle(
        id: String = "game-view-model-tests-\(UUID().uuidString)",
        date: String = "2026-06-13",
        size: Int = 2
    ) -> Puzzle {
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

        var cells = Array(
            repeating: Array(
                repeating: CellData(letter: nil, clueNumber: nil, acrossClueId: nil, downClueId: nil),
                count: size
            ),
            count: size
        )
        cells[0][0] = CellData(letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: nil)
        cells[0][1] = CellData(letter: "B", clueNumber: nil, acrossClueId: 0, downClueId: nil)

        return Puzzle(
            id: id,
            puzzleNumber: 1,
            date: date,
            size: size,
            cells: cells,
            clues: [clue]
        )
    }

    private func makeTwoAnswerPuzzle() -> Puzzle {
        let firstClue = Clue(
            id: 0,
            direction: .across,
            number: 1,
            text: "First two-letter answer",
            hint: "First answer",
            answer: "AB",
            startRow: 0,
            startCol: 0,
            length: 2
        )
        let secondClue = Clue(
            id: 1,
            direction: .across,
            number: 2,
            text: "Second two-letter answer",
            hint: "Second answer",
            answer: "CD",
            startRow: 1,
            startCol: 0,
            length: 2
        )

        return Puzzle(
            id: "game-view-model-two-answer-tests-\(UUID().uuidString)",
            puzzleNumber: 1,
            date: "2026-06-13",
            size: 2,
            cells: [
                [
                    CellData(letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: nil),
                    CellData(letter: "B", clueNumber: nil, acrossClueId: 0, downClueId: nil),
                ],
                [
                    CellData(letter: "C", clueNumber: 2, acrossClueId: 1, downClueId: nil),
                    CellData(letter: "D", clueNumber: nil, acrossClueId: 1, downClueId: nil),
                ],
            ],
            clues: [firstClue, secondClue]
        )
    }
}
