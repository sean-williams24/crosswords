import UIKit

final class HapticsEngine {

    enum HapticType {
        case letterEntered
        case wordCompleted
        case puzzleCompleted
        case hintUsed
        case clueNavigated
    }

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        lightImpact.prepare()
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
        }
    }
}
