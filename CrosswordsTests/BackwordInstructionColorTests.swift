import Foundation
import Testing

@Suite("Backword instruction colour")
struct BackwordInstructionColorTests {
    @Test("The decorative bulb stays bright yellow in both appearances", arguments: [false, true])
    func instructionIconIsBrightYellow(dark: Bool) throws {
        let icon = try components(named: "InstructionIcon", dark: dark)

        #expect(icon[0] > icon[1] && icon[1] > icon[2])
        #expect(icon[0] >= 0.95 && icon[1] >= 0.8 && icon[2] < 0.1)
        #expect(icon[3] == 1)
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
}
