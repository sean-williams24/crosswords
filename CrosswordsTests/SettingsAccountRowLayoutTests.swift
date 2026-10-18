import SwiftUI
import Testing
@testable import Backword

@Suite("Settings account row layout")
struct SettingsAccountRowLayoutTests {
    @Test("Standard text sizes keep the icon, account text, and chevron in one row",
          arguments: [DynamicTypeSize.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge])
    func standardSizes(size: DynamicTypeSize) {
        #expect(!SettingsAccountRowLayout.stacksVertically(for: size))
    }

    @Test("Accessibility text sizes put account text above the icon and chevron row",
          arguments: [DynamicTypeSize.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5])
    func accessibilitySizes(size: DynamicTypeSize) {
        #expect(SettingsAccountRowLayout.stacksVertically(for: size))
    }
}
