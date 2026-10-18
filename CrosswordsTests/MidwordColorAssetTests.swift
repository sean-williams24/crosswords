import Foundation
import Testing

@Suite("Midword colour assets")
struct MidwordColorAssetTests {
    @Test("Home card foreground is white in light mode")
    func lightForeground() throws {
        let colors = try loadColors(named: "MidwordHomeCardForeground")
        let light = try #require(colors.first { $0["appearances"] == nil })
        #expect(components(in: light) == ["red": "1.000", "green": "1.000", "blue": "1.000", "alpha": "1.000"])
    }

    @Test("Home card retains its existing dark foreground")
    func darkForeground() throws {
        let colors = try loadColors(named: "MidwordHomeCardForeground")
        let dark = try #require(colors.first {
            let appearances = $0["appearances"] as? [[String: String]]
            return appearances?.contains { $0["appearance"] == "luminosity" && $0["value"] == "dark" } == true
        })
        #expect(components(in: dark) == ["red": "0x00", "green": "0x00", "blue": "0x00", "alpha": "1.000"])
    }

    @Test("Gameplay on-accent foreground remains black in both appearances")
    func gameplayForeground() throws {
        let colors = try loadColors(named: "MidwordOnAccent")
        #expect(colors.count == 1)
        let color = try #require(colors.first)
        #expect(color["appearances"] == nil)
        #expect(components(in: color) == ["red": "0x00", "green": "0x00", "blue": "0x00", "alpha": "1.000"])
    }

    @Test("Light gameplay and stats use the instructions background and text")
    func lightPaletteMatchesInstructions() throws {
        for (midwordName, appName) in [("MidwordBackground", "Background"), ("MidwordText", "TextPrimary")] {
            let midwordColor = try appearance(named: midwordName, dark: false)
            let appColor = try appearance(named: appName, dark: false)
            #expect(components(in: midwordColor) == components(in: appColor))
        }
    }

    @Test("Dark gameplay and stats retain charcoal and white")
    func darkPalette() throws {
        let background = try appearance(named: "MidwordBackground", dark: true)
        let text = try appearance(named: "MidwordText", dark: true)
        #expect(components(in: background) == ["red": "0x1F", "green": "0x1F", "blue": "0x1F", "alpha": "1.000"])
        #expect(components(in: text) == ["red": "1.000", "green": "1.000", "blue": "1.000", "alpha": "1.000"])
    }

    @Test("Gameplay text has strong contrast in both appearances", arguments: [false, true])
    func textContrast(dark: Bool) throws {
        let background = try appearance(named: "MidwordBackground", dark: dark)
        let text = try appearance(named: "MidwordText", dark: dark)
        #expect(try contrastRatio(text, background) >= 7)
    }

    @Test("Light inactive borders are visible against the board")
    func lightInactiveCellBorder() throws {
        let border = try appearance(named: "MidwordInactiveCellBorder", dark: false)
        let background = try appearance(named: "MidwordBackground", dark: false)
        #expect(try contrastRatio(border, background) >= 3)
    }

    @Test("Dark inactive borders retain their existing appearance")
    func inactiveCellBorder() throws {
        let colors = try loadColors(named: "MidwordInactiveCellBorder")
        #expect(colors.count == 2)
        let color = try appearance(named: "MidwordInactiveCellBorder", dark: true)
        #expect(components(in: color) == ["red": "0x52", "green": "0x52", "blue": "0x52", "alpha": "1.000"])
    }

    private func appearance(named name: String, dark: Bool) throws -> [String: Any] {
        let colors = try loadColors(named: name)
        return try #require(colors.first { entry in
            let appearances = entry["appearances"] as? [[String: String]]
            let isDark = appearances?.contains {
                $0["appearance"] == "luminosity" && $0["value"] == "dark"
            } == true
            return dark ? isDark : appearances == nil
        })
    }

    private func contrastRatio(_ first: [String: Any], _ second: [String: Any]) throws -> Double {
        let firstLuminance = try luminance(first)
        let secondLuminance = try luminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05)
            / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func luminance(_ entry: [String: Any]) throws -> Double {
        let values = try #require(components(in: entry))
        return try [("red", 0.2126), ("green", 0.7152), ("blue", 0.0722)].reduce(0) { sum, channel in
            let value = try #require(values[channel.0])
            let component: Double
            if value.hasPrefix("0x") {
                component = Double(try #require(Int(value.dropFirst(2), radix: 16))) / 255
            } else {
                component = try #require(Double(value))
            }
            let linear = component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            return sum + linear * channel.1
        }
    }

    private func loadColors(named name: String) throws -> [[String: Any]] {
        let url = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backword/Resources/Assets.xcassets/\(name).colorset/Contents.json")
        let data = try Data(contentsOf: url)
        let asset = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(asset["colors"] as? [[String: Any]])
    }

    private func components(in entry: [String: Any]) -> [String: String]? {
        let color = entry["color"] as? [String: Any]
        return color?["components"] as? [String: String]
    }
}
