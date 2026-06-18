import SwiftUI
import Combine

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Published State

    @Published var puzzle: Puzzle
    @Published var progress: UserProgress
    @Published var selectedRow: Int = 0
    @Published var selectedCol: Int = 0
    @Published var activeDirection: Direction = .across
    @Published var activeClue: Clue?
    @Published var isZenMode: Bool = false
    @Published var showHint: Bool = false
    @Published var showClueList: Bool = false
    @Published var isComplete: Bool = false
    @Published var showAlreadyAnswered: Bool = false
    @Published var adBonusHints: Int = 0

    private let haptics = HapticsEngine()
    private var zenTimer: Timer?

    // MARK: - Init

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        var loaded = UserProgress.load(puzzleId: puzzle.id)
            ?? UserProgress(
                puzzleId: puzzle.id,
                size: puzzle.size,
                puzzleDate: puzzle.date,
                totalClues: puzzle.clues.count,
                isWeekly: puzzle.size > 12
            )
        // Back-fill metadata for legacy progress files
        if loaded.puzzleDate == nil {
            loaded.puzzleDate = puzzle.date
            loaded.totalClues = puzzle.clues.count
            loaded.isWeekly = puzzle.size > 12
            loaded.save()
        }
        self.progress = loaded

        // Select the first white cell
        if let first = firstWhiteCell() {
            selectedRow = first.row
            selectedCol = first.col
        }
        updateActiveClue()
    }

    // MARK: - Cell State

    func enteredLetter(row: Int, col: Int) -> Character? {
        guard let str = progress.entries[row][col], let ch = str.first else { return nil }
        return ch
    }

    func isSelected(row: Int, col: Int) -> Bool {
        row == selectedRow && col == selectedCol
    }

    func isInActiveWord(row: Int, col: Int) -> Bool {
        guard let clue = activeClue else { return false }
        return clue.cells.contains { $0.row == row && $0.col == col }
    }

    func isCompleted(row: Int, col: Int) -> Bool {
        guard let cell = cellData(row: row, col: col) else { return false }
        var done = false
        if let acrossId = cell.acrossClueId {
            done = done || progress.completedClueIds.contains(acrossId)
        }
        if let downId = cell.downClueId {
            done = done || progress.completedClueIds.contains(downId)
        }
        return done
    }

    func cellData(row: Int, col: Int) -> CellData? {
        guard row >= 0, row < puzzle.size, col >= 0, col < puzzle.size else { return nil }
        return puzzle.cells[row][col]
    }

    // MARK: - Selection

    func selectCell(row: Int, col: Int) {
        guard let cell = cellData(row: row, col: col), !cell.isBlack else { return }

        if row == selectedRow && col == selectedCol {
            // Tap same cell — toggle direction
            toggleDirection()
        } else {
            selectedRow = row
            selectedCol = col

            let clues = puzzle.cluesAt(row: row, col: col)

            // 1. Determine if this cell is the START of the across/down words
            let isNumberedCell = (cell.clueNumber != nil)
            let startsAcross = isNumberedCell && (clues.across?.number == cell.clueNumber)
            let startsDown = isNumberedCell && (clues.down?.number == cell.clueNumber)

            // 2. Pick direction based on whether it's a numbered starting cell
            if startsAcross && !startsDown {
                // It's the start of an Across word only (e.g., taps 12-Across)
                activeDirection = .across
            } else if startsDown && !startsAcross {
                // It's the start of a Down word only (e.g., taps 9-Down)
                activeDirection = .down
            } else if startsAcross && startsDown {
                // It starts BOTH an Across and Down word.
                // Keep the current activeDirection, user can tap again to toggle.
            } else {
                // 3. Fallback for non-numbered cells (middle of a word)
                if clues.across != nil && clues.down == nil {
                    activeDirection = .across
                } else if clues.across == nil && clues.down != nil {
                    activeDirection = .down
                }
                // else it intersects both, so keep current direction
            }
        }

        updateActiveClue()
        haptics.play(.clueNavigated)
    }

    func toggleDirection() {
        let clues = puzzle.cluesAt(row: selectedRow, col: selectedCol)
        switch activeDirection {
        case .across:
            if clues.down != nil { activeDirection = .down }
        case .down:
            if clues.across != nil { activeDirection = .across }
        }
        updateActiveClue()
    }

    // MARK: - Clue Navigation

    func navigateToClue(_ clue: Clue) {
        activeDirection = clue.direction
        selectedRow = clue.startRow
        selectedCol = clue.startCol

        // Move to first empty cell in the word if possible
        for cell in clue.cells {
            if progress.entries[cell.row][cell.col] == nil {
                selectedRow = cell.row
                selectedCol = cell.col
                break
            }
        }

        activeClue = clue
        haptics.play(.clueNavigated)
    }

    func nextClue() {
        guard let current = activeClue else { return }
        let clues = activeDirection == .across ? puzzle.acrossClues : puzzle.downClues
        if let idx = clues.firstIndex(where: { $0.id == current.id }) {
            let next = clues[(idx + 1) % clues.count]
            navigateToClue(next)
        }
    }

    func previousClue() {
        guard let current = activeClue else { return }
        let clues = activeDirection == .across ? puzzle.acrossClues : puzzle.downClues
        if let idx = clues.firstIndex(where: { $0.id == current.id }) {
            let prev = clues[(idx - 1 + clues.count) % clues.count]
            navigateToClue(prev)
        }
    }

    // MARK: - Input

    func enterLetter(_ letter: Character) {
        guard !puzzle.cells[selectedRow][selectedCol].isBlack else { return }
        let entered = String(letter).uppercased()

        if AppSettings.shared.crosswordCorrectHighlight && isCompleted(row: selectedRow, col: selectedCol) {
            guard progress.entries[selectedRow][selectedCol] == entered else { return }
            haptics.play(.letterEntered)
            advanceToNextCell()
            saveProgress()
            return
        }

        progress.entries[selectedRow][selectedCol] = entered
        haptics.play(.letterEntered)

        checkWordCompletion()
        advanceToNextCell()
        saveProgress()
    }

    func deleteLetter() {
        let lockEnabled = AppSettings.shared.crosswordCorrectHighlight

        if lockEnabled && isCompleted(row: selectedRow, col: selectedCol) {
            moveToPreviousCell()
            return
        }

        if progress.entries[selectedRow][selectedCol] != nil {
            progress.entries[selectedRow][selectedCol] = nil
        } else {
            moveToPreviousCell()
            if !(lockEnabled && isCompleted(row: selectedRow, col: selectedCol)) {
                progress.entries[selectedRow][selectedCol] = nil
            }
        }
        saveProgress()
    }

    // MARK: - Hints

    func useHint() {
        guard let clue = activeClue else { return }

        // Don't consume a hint if the clue is already fully answered
        if activeClueIsAlreadyAnswered {
            showAlreadyAnswered = true
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showAlreadyAnswered = false
            }
            return
        }

        if showHint {
            // Toggle back to original clue — free, already paid
            showHint = false
        } else if progress.hintedClueIds.contains(clue.id) {
            // Already paid for this hint in a previous tap — show it free
            showHint = true
        } else {
            // First time hinting this clue — charge one hint
            showHint = true
            progress.hintedClueIds.insert(clue.id)
            progress.hintsUsed += 1
            haptics.play(.hintUsed)
            saveProgress()
        }
    }

    @discardableResult
    func grantRewardedHint() -> Bool {
        guard activeClue != nil else { return false }

        guard !activeClueIsAlreadyAnswered else {
            useHint()
            return false
        }

        if activeClueIsHinted {
            showHint = true
            return true
        }

        adBonusHints += 1
        useHint()
        return true
    }

    var currentClueText: String {
        guard let clue = activeClue else { return "" }
        return showHint ? clue.hint : clue.text
    }

    var activeClueIsHinted: Bool {
        guard let clue = activeClue else { return false }
        return progress.hintedClueIds.contains(clue.id)
    }

    private var activeClueIsAlreadyAnswered: Bool {
        guard let clue = activeClue else { return false }
        return clue.cells.allSatisfy { progress.entries[$0.row][$0.col] != nil }
    }

    // MARK: - Zen Mode

    private func activateZenMode() {
        zenTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.4)) {
            isZenMode = true
        }
        zenTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.6)) {
                    self?.isZenMode = false
                }
            }
        }
    }

    func deactivateZenMode() {
        zenTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.4)) {
            isZenMode = false
        }
    }

    // MARK: - Completion Detection

    private func checkWordCompletion() {
        guard let clue = activeClue else { return }
        checkClueCompletion(clue)

        // Also check the crossing clue
        let crossClues = puzzle.cluesAt(row: selectedRow, col: selectedCol)
        if activeDirection == .across, let downClue = crossClues.down {
            checkClueCompletion(downClue)
        } else if activeDirection == .down, let acrossClue = crossClues.across {
            checkClueCompletion(acrossClue)
        }
    }

    private func checkClueCompletion(_ clue: Clue) {
        guard !progress.completedClueIds.contains(clue.id) else { return }

        let enteredWord = clue.cells.compactMap { progress.entries[$0.row][$0.col] }.joined()
        if enteredWord.uppercased() == clue.answer.uppercased() {
            progress.completedClueIds.insert(clue.id)
            haptics.play(.wordCompleted)

            // Check full puzzle completion
            if progress.completedClueIds.count == puzzle.clues.count {
                progress.completedAt = Date()
                isComplete = true
                haptics.play(.puzzleCompleted)
                recordRating()
            }
        }
    }

    private func recordRating() {
        let ratingService = OverallRatingService()
        // Determine if this is a weekly puzzle (size > 12) vs daily
        if puzzle.size > 12 {
            ratingService.recordWeeklyCrossword(
                completedClues: progress.completedClueIds.count,
                totalClues: puzzle.clues.count,
                date: puzzle.date,
                hintsUsed: progress.hintsUsed
            )
        } else {
            ratingService.recordDailyCrossword(
                completedClues: progress.completedClueIds.count,
                totalClues: puzzle.clues.count,
                date: puzzle.date,
                hintsUsed: progress.hintsUsed
            )
        }
    }

    // MARK: - Navigation Helpers

    private func advanceToNextCell() {
        guard let clue = activeClue else { return }
        let cells = clue.cells
        guard let currentIdx = cells.firstIndex(where: { $0.row == selectedRow && $0.col == selectedCol }) else { return }

        // Try to find the next empty cell in this word
        for i in (currentIdx + 1)..<cells.count {
            if progress.entries[cells[i].row][cells[i].col] == nil {
                selectedRow = cells[i].row
                selectedCol = cells[i].col
                return
            }
        }

        // All remaining cells filled — just move to the next cell if possible
        let nextIdx = currentIdx + 1
        if nextIdx < cells.count {
            selectedRow = cells[nextIdx].row
            selectedCol = cells[nextIdx].col
        }
    }

    private func moveToPreviousCell() {
        guard let clue = activeClue else { return }
        let cells = clue.cells
        guard let currentIdx = cells.firstIndex(where: { $0.row == selectedRow && $0.col == selectedCol }) else { return }

        if currentIdx > 0 {
            selectedRow = cells[currentIdx - 1].row
            selectedCol = cells[currentIdx - 1].col
        }
    }

    private func updateActiveClue() {
        let clues = puzzle.cluesAt(row: selectedRow, col: selectedCol)
        switch activeDirection {
        case .across: activeClue = clues.across ?? clues.down
        case .down:   activeClue = clues.down ?? clues.across
        }
        showHint = false
    }

    private func firstWhiteCell() -> (row: Int, col: Int)? {
        for row in 0..<puzzle.size {
            for col in 0..<puzzle.size {
                if !puzzle.cells[row][col].isBlack { return (row, col) }
            }
        }
        return nil
    }

    private func saveProgress() {
        progress.save()
    }
}
