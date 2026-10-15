import Foundation
import Testing

@Suite("Backword instruction colour")
struct BackwordInstructionColorTests {
    @Test("The bulb is yellow and visible against its card in both appearances", arguments: [false, true])
    func instructionIconContrast(dark: Bool) throws {
        let icon = try components(named: "InstructionIcon", dark: dark)
        let surface = try components(named: "Surface", dark: dark)

        #expect(icon[0] > icon[1] && icon[1] > icon[2])
        #expect(icon[1] >= 0.45 && icon[2] < 0.1)
        #expect(icon[3] == 1)

        let iconLuminance = luminance(icon)
        let surfaceLuminance = luminance(surface)
        let contrast = (max(iconLuminance, surfaceLuminance) + 0.05)
            / (min(iconLuminance, surfaceLuminance) + 0.05)
        #expect(contrast >= 3)
    }

    private func components(named name: String, dark: Bool) throws -> [Double] {
        let url = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backword/Resources/Assets.xcassets/\(name).colorset/Contents.json")
        let asset = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let colors = try #require(asset["colors"] as? [[String: Any]])
        let entry = try #require(colors.first { entry in
            let appearances = entry["appearances"] as? [[String: String]]
            let isDark = appearances?.contains {
                $0["appearance"] == "luminosity" && $0["value"] == "dark"
            } == true
            return dark ? isDark : appearances == nil
        })
        let color = try #require(entry["color"] as? [String: Any])
        let values = try #require(color["components"] as? [String: String])
        return try ["red", "green", "blue", "alpha"].map { key in
            let value = try #require(values[key])
            return try #require(Double(value))
        }
    }

    private func luminance(_ components: [Double]) -> Double {
        zip(components, [0.2126, 0.7152, 0.0722]).reduce(0) { sum, channel in
            let linear = channel.0 <= 0.04045
                ? channel.0 / 12.92
                : pow((channel.0 + 0.055) / 1.055, 2.4)
            return sum + linear * channel.1
        }
    }
}
