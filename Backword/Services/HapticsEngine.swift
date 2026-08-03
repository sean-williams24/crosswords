import UIKit

protocol HapticsPlaying: AnyObject {
    func play(_ type: HapticsEngine.HapticType)
}

final class HapticsEngine: HapticsPlaying {

    enum HapticType: Equatable {
        case letterEntered
        case wordCompleted
        case puzzleCompleted
        case hintUsed
        case clueNavigated
        case backwordGuessIncorrect
        case backwordGuessProgress
        case backwordGameWon
        case backwordGameLost
        case backwordCompletionLetterRevealed
    }

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
    }

    func play(_ type: HapticType) {
        switch type {
        case .letterEntered:
            lightImpact.impactOccurred()

        case .wordCompleted:
            notification.notificationOccurred(.success)

        case .puzzleCompleted:
            heavyImpact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                notification.notificationOccurred(.success)
            }

        case .hintUsed:
            notification.notificationOccurred(.warning)

        case .clueNavigated:
            softImpact.impactOccurred()

        case .backwordGuessIncorrect:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()

        case .backwordGuessProgress:
            notification.notificationOccurred(.success)
            notification.prepare()

        case .backwordGameWon:
            heavyImpact.impactOccurred()
            heavyImpact.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                notification.notificationOccurred(.success)
                notification.prepare()
            }

        case .backwordGameLost:
            rigidImpact.impactOccurred()
            rigidImpact.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                notification.notificationOccurred(.error)
                notification.prepare()
            }

        case .backwordCompletionLetterRevealed:
            lightImpact.impactOccurred(intensity: 0.65)
            lightImpact.prepare()
        }
    }
}
