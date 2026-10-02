import Foundation
import Testing

@Suite("Midword home card colours")
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
