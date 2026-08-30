import Foundation
import Testing
@testable import Backword

private final class BackwordHapticsSpy: HapticsPlaying {
    private(set) var playedTypes: [HapticsEngine.HapticType] = []

    func play(_ type: HapticsEngine.HapticType) {
        playedTypes.append(type)
    }
}

@Suite("BackwordViewModel Tests")
@MainActor
struct BackwordViewModelTests {

    private func makeWord(_ word: String = "CASTLE") -> BackwordWord {
        BackwordWord(id: UUID().uuidString, date: "test-\(UUID().uuidString)", word: word, clue: "FORTRESS")
    }

    private func makeViewModel(
        _ word: String = "CASTLE",
        mode: BackwordMode = .normal,
        haptics: HapticsPlaying = BackwordHapticsSpy()
    ) -> BackwordViewModel {
        let word = makeWord(word)
        let settings = makeSettings(mode: mode)
        return BackwordViewModel(
            word: word,
            progress: BackwordProgress(date: word.date),
            settings: settings,
            haptics: haptics
        )
    }

    private func makeSettings(mode: BackwordMode = .normal) -> AppSettings {
        let suiteName = "BackwordViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(userDefaults: defaults)
        settings.backwordMode = mode
        return settings
    }

    private func withIsolatedSettings(_ assertions: (AppSettings) -> Void) {
        let suiteName = "BackwordViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        assertions(AppSettings(userDefaults: defaults))
    }

    // MARK: - Initial State

    @Test("Initial state reveals only the last letter")
    func initialRevealedLetters() async throws {
        let vm = makeViewModel()
        let revealed = vm.revealedLetters

        // Only the last letter (E) is shown at the start
        #expect(revealed[0] == nil)
        #expect(revealed[1] == nil)
        #expect(revealed[2] == nil)
        #expect(revealed[3] == nil)
        #expect(revealed[4] == nil)
        #expect(revealed[5] == Character("E"))
    }

    @Test("Initial guess count is 0")
    func initialGuessCount() async throws {
        let vm = makeViewModel()
        #expect(vm.guessCount == 0)
        #expect(vm.isComplete == false)
    }

    @Test("Explainer banner is visible before the first guess")
    func explainerBannerIsInitiallyVisible() {
        let vm = makeViewModel()

        #expect(vm.shouldShowExplainerBanner)
        #expect(vm.explainerText == "Guess the 6 letter word...")
    }

    @Test("Explainer gives more context after its delay")
    func explainerGivesMoreContextAfterDelay() {
        let vm = makeViewModel()

        vm.markExplainerDelayElapsed()

        #expect(vm.shouldShowExplainerBanner)
        #expect(vm.explainerText == "The clue is a word associated with the answer, or something connected to it.")
    }

    @Test("Explainer banner is hidden after the first guess")
    func explainerBannerIsHiddenAfterFirstGuess() {
        let vm = makeViewModel()
        vm.currentInput = "XXXXX"

        vm.submitGuess()

        #expect(!vm.shouldShowExplainerBanner)
    }

    @Test("New player receives onboarding instead of a rules update")
    func newPlayerReceivesOnboarding() {
        withIsolatedSettings { settings in
            #expect(settings.automaticBackwordInstructionsPresentation == .onboarding)
        }
    }

    @Test("Backword mode defaults to Easy and persists both values")
    func backwordModePersists() {
        let suiteName = "BackwordModeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(userDefaults: defaults)
        #expect(settings.backwordMode == .easy)

        settings.backwordMode = .easy
        #expect(AppSettings(userDefaults: defaults).backwordMode == .easy)

        settings.backwordMode = .normal
        #expect(AppSettings(userDefaults: defaults).backwordMode == .normal)
    }

    @Test("Dismissing onboarding records onboarding and the current rules version")
    func dismissingOnboardingRecordsCurrentRules() {
        withIsolatedSettings { settings in
            settings.markBackwordInstructionsSeen(.onboarding)

            #expect(settings.hasSeenBackwordOnboarding)
            #expect(settings.lastSeenBackwordRulesVersion == AppSettings.currentBackwordRulesVersion)
            #expect(settings.automaticBackwordInstructionsPresentation == nil)
        }
    }

    @Test("Returning player with legacy rules receives the update")
    func returningPlayerReceivesRulesUpdate() {
        withIsolatedSettings { settings in
            settings.hasSeenBackwordOnboarding = true
            settings.lastSeenBackwordRulesVersion = 1

            #expect(AppSettings.currentBackwordRulesVersion == 2)
            #expect(settings.automaticBackwordInstructionsPresentation == .rulesUpdate)
        }
    }

    @Test("Dismissing the rules update prevents it appearing again")
    func dismissingRulesUpdateRecordsCurrentVersion() {
        withIsolatedSettings { settings in
            settings.hasSeenBackwordOnboarding = true

            settings.markBackwordInstructionsSeen(.rulesUpdate)

            #expect(settings.lastSeenBackwordRulesVersion == AppSettings.currentBackwordRulesVersion)
            #expect(settings.automaticBackwordInstructionsPresentation == nil)
        }
    }

    @Test("Opening instructions manually does not change announcement state")
    func manualInstructionsDoNotChangeAnnouncementState() {
        withIsolatedSettings { settings in
            settings.hasSeenBackwordOnboarding = true
            settings.lastSeenBackwordRulesVersion = 0

            settings.markBackwordInstructionsSeen(.manual)

            #expect(settings.automaticBackwordInstructionsPresentation == .rulesUpdate)
        }
    }

    @Test("Resetting Backword onboarding clears the rules version")
    func resettingOnboardingClearsRulesVersion() {
        withIsolatedSettings { settings in
            settings.markBackwordInstructionsSeen(.onboarding)

            settings.resetBackwordOnboarding()

            #expect(settings.hasSeenBackwordOnboarding == false)
            #expect(settings.lastSeenBackwordRulesVersion == 0)
            #expect(settings.automaticBackwordInstructionsPresentation == .onboarding)
        }
    }

    @Test("Resetting the rules notice reproduces the returning-player update")
    func resettingRulesNoticeReplaysUpdate() {
        withIsolatedSettings { settings in
            settings.markBackwordInstructionsSeen(.onboarding)

            settings.resetBackwordRulesNotice()

            #expect(settings.hasSeenBackwordOnboarding)
            #expect(settings.lastSeenBackwordRulesVersion == 0)
            #expect(settings.automaticBackwordInstructionsPresentation == .rulesUpdate)
        }
    }

    @Test("Guess history identifies the connected correct suffix")
    func guessHistoryIdentifiesConnectedCorrectSuffix() {
        let vm = makeViewModel()

        #expect(vm.correctlyPositionedSuffixIndices(for: "XAXTLE") == Set([3, 4, 5]))
    }

    @Test("Guess history does not highlight disconnected correct letters")
    func guessHistoryDoesNotHighlightDisconnectedCorrectLetters() {
        let vm = makeViewModel()

        #expect(vm.correctlyPositionedSuffixIndices(for: "CXXXXE") == Set([5]))
    }

    @Test("Guess history highlights no cells when the ending is incorrect")
    func guessHistoryHighlightsNoCellsForIncorrectEnding() {
        let vm = makeViewModel()

        #expect(vm.correctlyPositionedSuffixIndices(for: "CASTLY").isEmpty)
    }

    @Test("Guess history keeps every guess after a completed win")
    func guessHistoryKeepsEveryGuessAfterCompletedWin() {
        let word = makeWord()
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["BRIDGX", "CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Date()

        let vm = BackwordViewModel(word: word, progress: progress)

        #expect(vm.isComplete)
        #expect(vm.guessesForHistory == ["BRIDGX", "CASTLE"])
    }

    @Test("Backword progress has no score before completion")
    func progressHasNoScoreBeforeCompletion() {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["BRIDGX", "FXASXE"]

        #expect(progress.completedScore == nil)
    }

    @Test("Winning Backword progress scores from guess count")
    func winningProgressScoresFromGuessCount() {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Self.date("2026-07-09 12:00:00")

        #expect(progress.completedScore == 3)
    }

    @Test("Archive Backword win scores zero")
    func archiveBackwordWinScoresZero() {
        var progress = BackwordProgress(date: "2026-07-08")
        progress.guesses = ["BRIDGX", "CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Self.date("2026-07-09 12:00:00")

        #expect(progress.wasCompletedOnReleaseDate == false)
        #expect(progress.completedScore == 0)
    }

    @Test("Archive Backword completion does not update player statistics")
    func archiveBackwordCompletionDoesNotUpdatePlayerStatistics() {
        let word = BackwordWord(
            id: UUID().uuidString,
            date: "2000-01-01",
            word: "CASTLE",
            clue: "FORTRESS"
        )
        let vm = BackwordViewModel(
            word: word,
            progress: BackwordProgress(date: word.date),
            haptics: BackwordHapticsSpy()
        )
        let gamesPlayedBeforeCompletion = vm.stats.gamesPlayed
        defer { BackwordProgress.delete(date: word.date) }

        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.progress.completedScore == 0)
        #expect(vm.stats.gamesPlayed == gamesPlayedBeforeCompletion)
    }

    @Test("Failed Backword progress scores zero")
    func failedProgressScoresZero() {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["BRIDGX", "FXASXE", "MAXXXX", "PUZZLE", "CASTER"]
        progress.completedAt = Date()

        #expect(progress.completedScore == 0)
    }

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string)!
    }

    @Test("Saving Backword progress posts changed date notification")
    func savingProgressPostsChangedDateNotification() {
        let date = "test-\(UUID().uuidString)"
        var receivedDate: String?
        let observer = NotificationCenter.default.addObserver(
            forName: .backwordProgressDidChange,
            object: nil,
            queue: nil
        ) { notification in
            receivedDate = notification.userInfo?[BackwordProgress.changedDateUserInfoKey] as? String
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            BackwordProgress.delete(date: date)
        }

        BackwordProgress(date: date).save()

        #expect(receivedDate == date)
    }

    // MARK: - Reveal Logic

    @Test("First wrong guess reveals no new letters")
    func firstWrongGuessRevealsNothing() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "XXXXX"

        vm.submitGuess()

        #expect(vm.revealedLetters == [nil, nil, nil, nil, nil, Character("E")])
        #expect(vm.unrevealedCount == 5)
        #expect(vm.newlyRevealedIndex == nil)
    }

    @Test("Correctly positioned suffix reveals immediately in the main letter row")
    func correctlyPositionedSuffixRevealsImmediately() {
        let vm = makeViewModel("CHEESY")
        vm.currentInput = "DREES"

        vm.submitGuess()

        #expect(vm.progress.guesses == ["DREESY"])
        #expect(vm.revealedLetters == [nil, nil, Character("E"), Character("E"), Character("S"), Character("Y")])
        #expect(vm.unrevealedCount == 2)
        #expect(vm.newlyRevealedIndex == 2)
    }

    @Test("Wrong guess plays incorrect feedback")
    func wrongGuessPlaysIncorrectFeedback() {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel(haptics: haptics)
        vm.currentInput = "XXXXX"

        vm.submitGuess()

        #expect(haptics.playedTypes == [.backwordGuessIncorrect])
    }

    @Test("Guess extending the correct suffix plays progress feedback")
    func correctSuffixProgressPlaysSuccessFeedback() {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel("CHEESY", haptics: haptics)
        vm.currentInput = "DREES"

        vm.submitGuess()

        #expect(haptics.playedTypes == [.backwordGuessProgress])
    }

    @Test("Automatic reveal without a matching guessed letter stays incorrect feedback")
    func automaticRevealStaysIncorrectFeedback() {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel(haptics: haptics)

        for _ in 0..<2 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        #expect(vm.newlyRevealedIndex == 4)
        #expect(haptics.playedTypes == [
            .backwordGuessIncorrect,
            .backwordGuessIncorrect
        ])
    }

    @Test("Second wrong guess reveals the penultimate letter")
    func secondWrongGuessRevealsPenultimateLetter() {
        let vm = makeViewModel("CASTLE")
        for _ in 0..<2 {
            vm.currentInput = "XXXXX"
            vm.submitGuess()
        }

        #expect(vm.revealedLetters == [nil, nil, nil, nil, Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 4)
        #expect(vm.newlyRevealedIndex == 4)
    }

    @Test("Third wrong guess reveals the next letter from the end")
    func thirdWrongGuessRevealsNextLetterFromEnd() {
        let vm = makeViewModel("CASTLE")
        for _ in 0..<3 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        #expect(vm.revealedLetters == [nil, nil, nil, Character("T"), Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 3)
        #expect(vm.newlyRevealedIndex == 3)
    }

    @Test("Fourth wrong guess reveals no new letter")
    func fourthWrongGuessRevealsNothing() {
        let vm = makeViewModel("CASTLE")
        for _ in 0..<3 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }
        let revealedAfterThirdGuess = vm.revealedLetters

        vm.currentInput = "XXX"
        vm.submitGuess()

        #expect(vm.revealedLetters == [nil, nil, nil, Character("T"), Character("L"), Character("E")])
        #expect(vm.revealedLetters == revealedAfterThirdGuess)
        #expect(vm.unrevealedCount == 3)
    }

    @Test("Correct letters disconnected from the ending remain hidden")
    func disconnectedCorrectLettersRemainHidden() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "CXXXX"

        vm.submitGuess()

        #expect(vm.progress.guesses == ["CXXXXE"])
        #expect(vm.revealedLetters == [nil, nil, nil, nil, nil, Character("E")])
    }

    @Test("Saved progress with two wrong guesses reveals the final two letters")
    func savedProgressWithTwoWrongGuessesRevealsFinalTwoLetters() {
        let word = makeWord("CASTLE")
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["XXXXXE", "BXXXXE"]

        let vm = BackwordViewModel(word: word, progress: progress)

        #expect(vm.revealedLetters == [nil, nil, nil, nil, Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 4)
    }

    @Test("Saved progress applies the same reveal after third and fourth wrong guesses")
    func savedProgressAppliesScheduledReveals() {
        let word = makeWord("CASTLE")
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["XXXXXE", "CXXXXE", "BXXXXE"]

        var vm = BackwordViewModel(word: word, progress: progress)

        #expect(vm.revealedLetters == [nil, nil, nil, Character("T"), Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 3)

        progress.guesses.append("XXXXLE")
        vm = BackwordViewModel(word: word, progress: progress)

        #expect(vm.revealedLetters == [nil, nil, nil, Character("T"), Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 3)
    }

    @Test("Easy mode reveals one additional letter after every wrong guess")
    func easyModeRevealsAfterEveryWrongGuess() {
        let vm = makeViewModel("CASTLE", mode: .easy)
        let expectedReveals: [[Character?]] = [
            [nil, nil, nil, nil, Character("L"), Character("E")],
            [nil, nil, nil, Character("T"), Character("L"), Character("E")],
            [nil, nil, Character("S"), Character("T"), Character("L"), Character("E")],
            [nil, Character("A"), Character("S"), Character("T"), Character("L"), Character("E")]
        ]

        for expected in expectedReveals {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
            #expect(vm.revealedLetters == expected)
        }

        #expect(vm.unrevealedCount == 1)
    }

    @Test("Easy mode reveals a longer correctly positioned suffix immediately")
    func easyModeRevealsLongerCorrectSuffix() {
        let vm = makeViewModel("CHEESY", mode: .easy)
        vm.currentInput = "DREES"

        vm.submitGuess()

        #expect(vm.revealedLetters == [
            nil,
            nil,
            Character("E"),
            Character("E"),
            Character("S"),
            Character("Y")
        ])
    }

    @Test("Easy mode derives reveals from saved progress")
    func easyModeDerivesRevealsFromSavedProgress() {
        let word = makeWord("CASTLE")
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["XXXXXE", "XXXXLE", "XXXTLE", "XXSTLE"]
        let settings = makeSettings(mode: .easy)

        let vm = BackwordViewModel(word: word, progress: progress, settings: settings)

        #expect(vm.revealedLetters == [
            nil,
            Character("A"),
            Character("S"),
            Character("T"),
            Character("L"),
            Character("E")
        ])
    }

    @Test("Changing mode recalculates reveals, persists the setting, and clears input")
    func changingModeUpdatesActiveGame() {
        let word = makeWord("CASTLE")
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["XXXXXE", "BXXXXE"]
        let settings = makeSettings()
        let vm = BackwordViewModel(word: word, progress: progress, settings: settings)
        vm.currentInput = "CA"

        vm.setMode(.easy)

        #expect(settings.backwordMode == .easy)
        #expect(vm.mode == .easy)
        #expect(vm.currentInput.isEmpty)
        #expect(vm.revealedLetters == [
            nil,
            nil,
            nil,
            Character("T"),
            Character("L"),
            Character("E")
        ])

        vm.currentInput = "C"
        vm.setMode(.normal)

        #expect(settings.backwordMode == .normal)
        #expect(vm.currentInput.isEmpty)
        #expect(vm.revealedLetters == [
            nil,
            nil,
            nil,
            nil,
            Character("L"),
            Character("E")
        ])
    }

    // MARK: - Win Condition

    @Test("Correct guess triggers win")
    func correctGuessTriggerWin() async throws {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel("CASTLE", haptics: haptics)
        // Unrevealed [0,1,2,3,4]. Type C,A,S,T,L to form CASTLE.
        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.isComplete == true)
        #expect(vm.isWon == true)
        #expect(vm.isFailed == false)
        #expect(vm.guessCount == 1)
        #expect(haptics.playedTypes == [.backwordGameWon])
    }

    @Test("Correct guess after wrong guesses wins")
    func correctGuessAfterWrongGuesses() async throws {
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        for _ in 0..<3 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }
        // After three wrong guesses, TLE is supplied by the revealed cells.
        vm.currentInput = "CAS"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 4)
    }

    // MARK: - Fail Condition

    @Test("Five wrong guesses causes failure")
    func fiveWrongGuesessFail() async throws {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel("CASTLE", haptics: haptics)
        vm.wordValidator = { _ in true }
        for _ in 0..<5 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        #expect(vm.isFailed == true)
        #expect(vm.isWon == false)
        #expect(vm.isComplete == true)
        #expect(vm.didComplete == true)
        #expect(vm.guessCount == 5)
        #expect(haptics.playedTypes == [
            .backwordGuessIncorrect,
            .backwordGuessIncorrect,
            .backwordGuessIncorrect,
            .backwordGuessIncorrect,
            .backwordGameLost
        ])
    }

    @Test("No more guesses accepted after game complete")
    func noGuessesAfterComplete() async throws {
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        for _ in 0..<5 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }
        // Game is now failed; extra submission must be rejected
        vm.currentInput = "X"
        vm.submitGuess()

        #expect(vm.guessCount == 5)
    }

    #if DEBUG
    @Test("Debug failure simulation creates a transient failed game")
    func debugFailureSimulation() {
        let vm = makeViewModel("CASTLE")

        vm.debugSimulateFailure()

        #expect(vm.isFailed == true)
        #expect(vm.isWon == false)
        #expect(vm.didComplete == true)
        #expect(vm.guessCount == vm.maxGuesses)
        #expect(vm.progress.guesses.contains("CASTLE") == false)
    }
    #endif

    // MARK: - Input Validation

    @Test("Input shorter than required is rejected")
    func shortInputRejected() async throws {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel(haptics: haptics)
        // unrevealedCount == 5; "CA" (2 chars) is too short
        vm.currentInput = "CA"
        vm.submitGuess()
        #expect(vm.guessCount == 0)
        #expect(haptics.playedTypes.isEmpty)
    }

    @Test("onInputChange filters to uppercase alpha and caps at unrevealedCount")
    func inputChangeFilters() async throws {
        let vm = makeViewModel()
        // Initial unrevealedCount == 5; "castle123!!" filtered+capped = "CASTL"
        vm.onInputChange("castle123!!")
        #expect(vm.currentInput == "CASTL")
    }

    @Test("onInputChange truncates to unrevealedCount characters")
    func inputChangeTruncates() async throws {
        let vm = makeViewModel()
        // Initial unrevealedCount == 5
        vm.onInputChange("ABCDEFGH")
        #expect(vm.currentInput == "ABCDE")
    }

    @Test("Keyboard letter entry uppercases and caps at unrevealed count")
    func keyboardLetterEntryUppercasesAndCaps() async throws {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel(haptics: haptics)

        for letter in "castle" {
            vm.enterLetter(letter)
        }

        #expect(vm.currentInput == "CASTL")
        #expect(haptics.playedTypes == Array(repeating: .letterEntered, count: 6))
    }

    @Test("Keyboard delete removes the last typed letter")
    func keyboardDeleteRemovesLastTypedLetter() async throws {
        let haptics = BackwordHapticsSpy()
        let vm = makeViewModel(haptics: haptics)

        vm.onInputChange("CAST")
        vm.deleteLetter()

        #expect(vm.currentInput == "CAS")
        #expect(haptics.playedTypes == [.letterEntered])
    }

    // MARK: - Clue Hint

    @Test("Clue hint sets flag")
    func clueHintSetsFlag() async throws {
        let vm = makeViewModel()
        #expect(vm.progress.clueRevealed == false)
        vm.revealClueHint()
        #expect(vm.progress.clueRevealed == true)
    }

    @Test("Clue hint is idempotent")
    func clueHintIdempotent() async throws {
        let vm = makeViewModel()
        vm.revealClueHint()
        vm.revealClueHint()
        #expect(vm.progress.clueRevealed == true)
    }

    // MARK: - Letter Feedback

    @Test("lettersInWord returns matching characters")
    func lettersInWordReturnsMatches() async throws {
        let vm = makeViewModel("CASTLE")
        let matching = vm.lettersInWord(for: "CLOCKS")
        #expect(matching.contains("C"))
        #expect(matching.contains("L"))
        #expect(matching.contains("S"))
        #expect(!matching.contains("O"))
        #expect(!matching.contains("K"))
    }

    @Test("lettersInWord returns empty set when no matches")
    func lettersInWordNoMatches() async throws {
        let vm = makeViewModel("CASTLE")
        let matching = vm.lettersInWord(for: "BIRDY")
        #expect(matching.isEmpty)
    }

    // MARK: - Word Validation

    @Test("Any guess is accepted while word validation is disabled")
    func arbitraryGuessAccepted() async throws {
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in false }
        vm.currentInput = "XYZQB"  // 5 chars for unrevealed [0,1,2,3,4]
        vm.submitGuess()

        #expect(vm.guessCount == 1)
        #expect(vm.progress.guesses == ["XYZQBE"])
        #expect(vm.invalidWordMessage == nil)
    }
}
