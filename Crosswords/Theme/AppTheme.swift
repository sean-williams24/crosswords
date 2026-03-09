import SwiftUI

// MARK: - Semantic Colors

extension Color {
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appGridLine = Color("GridLine")
    static let appAccent = Color("Accent")
    static let appCorrect = Color("Correct")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextSecondary = Color("TextSecondary")
}

// MARK: - Typography

enum AppFont {
    static func header(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func gridLetter(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static func clueNumber(_ size: CGFloat = 8) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func clueLabel(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static func clueText(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .light, design: .default)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func statNumber(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Spacing & Layout

enum AppLayout {
    static let gridSpacing: CGFloat = 2
    static let cellCornerRadius: CGFloat = 2
    static let cardCornerRadius: CGFloat = 12
    static let screenPadding: CGFloat = 20
}
