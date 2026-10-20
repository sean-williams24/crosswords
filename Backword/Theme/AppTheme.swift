import SwiftUI

enum AppColorSchemePreference {
    static let lightValue = 1
    static let darkValue = 2
    static let systemValue = 3
    static let defaultValue = systemValue

    static func colorScheme(for value: Int) -> ColorScheme? {
        switch value {
        case lightValue: return .light
        case darkValue: return .dark
        default: return nil
        }
    }
}

// MARK: - Semantic Colors

extension Color {
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appGridLine = Color("GridLine")
    static let appAccent = Color("Accent")
    static let appInstructionIcon = Color("InstructionIcon")
    static let appCorrect = Color("Correct")
    static let appGaveUp = Color("GaveUp")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextHeading = Color("TextHeading")
    static let appTextSecondary = Color("TextSecondary")
    static let dailyCardBackground = Color("DailyCardBackground")
    static let dailyCardTitle = Color("DailyCardTitle")
    static let dailyCardDescription = Color("DailyCardDescription")
    static let homeCardBrightnessOverlay = Color.white
    static let homeArchiveBorder = Color.white
    static func homeCardProOnlyForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? .black : .white
    }
    static let solvedGold = Color("SolvedGold")
    static let appCrosswordBackground = Color("CrosswordBackground")
    static let backwordBackground = Color("BackwordBackground")
    static let shareCardDailyBackground = Color("ShareCardDaily")
    static let shareCardWeeklyBackground = Color("ShareCardWeekly")
    static let shareCardBackwordStatLabel = Color("ShareCardBackwordStatLabel")
    static let shareCardDailyStatLabel = Color("ShareCardDailyStatLabel")
    static let shareCardWeeklyStatLabel = Color("ShareCardWeeklyStatLabel")
    static let midwordBackground = Color("MidwordBackground")
    static let midwordAccent = Color("MidwordAccent")
    static let midwordInactiveCellBorder = Color("MidwordInactiveCellBorder")
    static let midwordText = Color("MidwordText")
    static let midwordOnAccent = Color("MidwordOnAccent")
    static let midwordHomeCardForeground = Color("MidwordHomeCardForeground")
    static let anagramOrange = Color("AnagramOrange")
    static let anagramHomeCardBackground = Color("AnagramHomeCardBackground")
    static let anagramSurface = Color("AnagramSurface")
    static let anagramInk = Color("AnagramInk")
    static let anagramOnOrange = Color("AnagramOnOrange")
}

enum AppGradient {
    // The stacked gameplay wordmark uses the same hard colour split as the web.
    static let midwordLogo = LinearGradient(
        stops: [
            .init(color: .midwordAccent, location: 0),
            .init(color: .midwordAccent, location: 0.49),
            .init(color: .midwordText, location: 0.49),
            .init(color: .midwordText, location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pro = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.65, blue: 0.25),
            Color(red: 0.78, green: 0.52, blue: 0.20),
            Color(red: 0.85, green: 0.65, blue: 0.25)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Keeps the home-screen Backword card visually consistent with its dark design
/// in either system appearance.
enum BackwordAppearance {
    static let colorScheme: ColorScheme = .dark
}

/// Pro Home cards retain their dark surface and readable content in both themes.
enum WeeklyCrosswordCardAppearance {
    static let colorScheme: ColorScheme = .dark
}

enum BackwordCardAppearance {
    /// The card keeps dark, high-contrast content, while its background follows
    /// the system appearance so Light Mode can use the pastel lavender asset.
    static func backgroundColorScheme(for systemColorScheme: ColorScheme) -> ColorScheme {
        systemColorScheme
    }

    static func correctCellStyle(for systemColorScheme: ColorScheme) -> BackwordCorrectCellStyle {
        systemColorScheme == .light ? .whiteHomeCard : .game
    }

    static func badgeBorderStyle(for systemColorScheme: ColorScheme) -> HomeCardBadgeBorderStyle {
        systemColorScheme == .light ? .white : .none
    }
}

enum BackwordCorrectCellStyle: Equatable {
    case game
    case whiteHomeCard
}

enum HomeCardBadgeBorderStyle: Equatable {
    case none
    case white
}

enum HomeCardAppearance {
    static let lightModeBrightnessOverlayOpacity = 0.1

    static func backgroundColorScheme(for systemColorScheme: ColorScheme) -> ColorScheme {
        systemColorScheme
    }

    static func shouldBrightenBackground(for colorScheme: ColorScheme) -> Bool {
        colorScheme == .light
    }
}

enum AdFreeExperienceButtonAppearance {
    static func backgroundOpacity(for colorScheme: ColorScheme, isArchiveCard: Bool) -> Double {
        isArchiveCard && colorScheme == .light ? 0.5 : 0.26
    }
}

// MARK: - Typography

enum AppFont {
    static let settingsAccountIcon: Font = .title3
    static let settingsRowChevron: Font = .caption.weight(.semibold)

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

    /// The share card is exported at a fixed 1080px canvas, so its typography
    /// must not change with the device's Dynamic Type setting.
    static func shareCardTitle(_ size: CGFloat) -> Font {
        .custom("Outfit-Bold", fixedSize: size)
    }

    static func shareCardValue(_ size: CGFloat) -> Font {
        .custom("Outfit-SemiBold", fixedSize: size)
    }
}

// MARK: - Spacing & Layout

struct AppLayout {
    let sizeClass: UserInterfaceSizeClass?

    // Statically available constants
    static let gridSpacing: CGFloat = 2
    static let cellCornerRadius: CGFloat = 2
    static let cardCornerRadius: CGFloat = 12
    static let homeCardLogoHeight: CGFloat = 56
    static let midwordHomeCardLogoHeight: CGFloat = 40
    static let homeCardLetterCellSize: CGFloat = 32
    static let cardHeightSmall: CGFloat = 144
    static let cardHeightLarge: CGFloat = 194
    static let settingsAccountRowSpacing: CGFloat = 12
    static let settingsAccountTextSpacing: CGFloat = 2
    static let settingsAccountTitleSize: CGFloat = 15
    static let screenPadding: CGFloat = 20
    static let screenPaddingLarge: CGFloat = 45
    static let anagramAnswerTileSpacing: CGFloat = 6
    static let anagramTrayTileSpacing: CGFloat = 8
    static let anagramBottomDockInset: CGFloat = 40
    static let anagramTrayPreferredTileSize: CGFloat = 52
    static let statsHistoryRowInset: CGFloat = 14
    static let statsHomeButtonVerticalPadding: CGFloat = 14
    static let statsHomeButtonHorizontalPadding: CGFloat = 8
    static let statsHomeBarVerticalPadding: CGFloat = 8
    static let minimumTouchTarget: CGFloat = 44
    static let statsHistoryScoreColumnWidth: CGFloat = 50
    static let statsHistoryAccessibleScoreColumnWidth: CGFloat = 60
    static let statsHistoryTimeColumnWidth: CGFloat = 72
    static let statsHistoryScoreChipSize: CGFloat = 24
    static let dailyCompletionGridWidth: CGFloat = 238
    static let weeklyCompletionGridWidth: CGFloat = 286
    static let completionGridSpacing: CGFloat = 2
    static let dailyCompletionGridLetterSize: CGFloat = 13
    static let weeklyCompletionGridLetterSize: CGFloat = 8
    static let completionSparkleSize: CGFloat = 15
    static let homeNavigationIconGlyphSize: CGFloat = 20
    static let homeTabBarTopPadding: CGFloat = 8
    static let homeArchiveContentSpacing: CGFloat = 10
    static let homeArchiveTitleSize: CGFloat = 24
    static let homeArchiveBorderWidth: CGFloat = 1
    static let onboardingInstructionIconSize: CGFloat = 18
    static let homeCardIssueNumberFontSize: CGFloat = 12
    static let sheetBackgroundBlurRadius: CGFloat = 4
    static let gameMaximumDynamicTypeSize: DynamicTypeSize = .xxxLarge
    static let midwordInputCellSize: CGFloat = 56
    static let midwordCompletionCellSize: CGFloat = 44
    static let midwordInputCellSpacing: CGFloat = 7
    static let midwordGuessCellSpacing: CGFloat = 6
    static let midwordCompletionCellSpacing: CGFloat = 8
    static let midwordCompletionCelebrationScale: CGFloat = 1.06

    var isiPad: Bool {
        sizeClass == .regular
    }

    var cardHeight: CGFloat {
        isiPad ? AppLayout.cardHeightLarge : AppLayout.cardHeightSmall
    }

    var homeHorizontalPadding: CGFloat {
        isiPad ? AppLayout.screenPaddingLarge : AppLayout.screenPadding
    }

    var iconSize: CGFloat {
        isiPad ? 54 : 30
    }

    var iconGlyphSize: CGFloat {
        isiPad ? 30 : 18
    }

    var iconTextSize: CGFloat {
        isiPad ? 20 : 16
    }
}
