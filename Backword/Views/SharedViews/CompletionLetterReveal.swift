import Foundation

/// Keeps each reveal and its haptic together, stopping when the sheet is dismissed.
enum CompletionLetterReveal {
    @MainActor
    static func run(
        steps: Range<Int>,
        interval: TimeInterval,
        haptics: HapticsPlaying,
        reveal: (Int) -> Void
    ) async -> Bool {
        for step in steps {
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return false
            }
            guard !Task.isCancelled else { return false }
            reveal(step)
            haptics.play(.backwordCompletionLetterRevealed)
        }
        return !Task.isCancelled
    }
}
