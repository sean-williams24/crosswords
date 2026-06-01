import SwiftUI

// MARK: - Semantic Colors

extension Color {
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appGridLine = Color("GridLine")
    static let appAccent = Color("Accent")
    static let appCorrect = Color("Correct")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextHeading = Color("TextHeading")
    static let appTextSecondary = Color("TextSecondary")
    static let dailyCardBackground = Color("DailyCardBackground")
    static let dailyCardTitle = Color("DailyCardTitle")
    static let solvedGold = Color("SolvedGold")
    static let appCrosswordBackground = Color("CrosswordBackground")
}

// MARK: - Typography

enum AppFont {
    static func header(_ size: CGFloat = 32) -> Font {
        .custom("Outfit-Bold", size: size, relativeTo: .largeTitle)
    }

    static func gridLetter(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
//        .custom("Outfit-SemiBold", size: size, relativeTo: .title3)
    }

    static func clueNumber(_ size: CGFloat = 8) -> Font {
        .custom("Outfit-Regular", size: size, relativeTo: .caption2)
    }

    static func clueLabel(_ size: CGFloat = 12) -> Font {
        .custom("Outfit-Black", size: size, relativeTo: .caption)
    }

    static func clueText(_ size: CGFloat = 15) -> Font {
        .custom("Inter-Thin", size: size, relativeTo: .body)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .custom("Outfit-Regular", size: size, relativeTo: .body)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .custom("Outfit-Regular", size: size, relativeTo: .footnote)
    }

    static func statNumber(_ size: CGFloat = 48) -> Font {
        .custom("Outfit-Bold", size: size, relativeTo: .largeTitle)
    }
}

// MARK: - Spacing & Layout

struct AppLayout {
    let sizeClass: UserInterfaceSizeClass?

    // Statically available constants
    static let gridSpacing: CGFloat = 2
    static let cellCornerRadius: CGFloat = 2
    static let cardCornerRadius: CGFloat = 12
    static let cardHeightSmall: CGFloat = 144
    static let cardHeightLarge: CGFloat = 194
    static let screenPadding: CGFloat = 20
    static let screenPaddingLarge: CGFloat = 45

    var isiPad: Bool {
        sizeClass == .regular
    }

    var cardHeight: CGFloat {
        isiPad ? AppLayout.cardHeightLarge : AppLayout.cardHeightSmall
    }

    var homeHorizontalPadding: CGFloat {
        isiPad ? AppLayout.screenPaddingLarge : AppLayout.screenPadding
    }
}
