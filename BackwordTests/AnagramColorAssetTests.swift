import Foundation
import Testing

@Suite("Anagram colour assets")
struct AnagramColorAssetTests {
    @Test("Gameplay orange retains its existing light and dark appearances")
    func anagramGameplayOrangeAppearances() throws {
        let asset = try #require(loadAsset(named: "AnagramOrange")["colors"] as? [[String: Any]])
        let anyAppearance = try #require(asset.first)
        let darkAppearance = try #require(
            asset.first { entry in
                let appearances = entry["appearances"] as? [[String: String]]
                return appearances?.contains { $0["appearance"] == "luminosity" && $0["value"] == "dark" } == true
            }
        )

        #expect(colorSpace(in: anyAppearance) == "display-p3")
        #expect(components(in: anyAppearance) == ["red": "1.000", "green": "0.604", "blue": "0.331", "alpha": "1.000"])
        #expect(colorSpace(in: darkAppearance) == "display-p3")
        #expect(components(in: darkAppearance) == ["red": "0.949", "green": "0.667", "blue": "0.412", "alpha": "1.000"])
    }

    @Test("Home card uses the web card orange only in dark mode")
    func anagramHomeCardAppearances() throws {
        let asset = try #require(loadAsset(named: "AnagramHomeCardBackground")["colors"] as? [[String: Any]])
        let anyAppearance = try #require(asset.first)
        let darkAppearance = try #require(
            asset.first { entry in
                let appearances = entry["appearances"] as? [[String: String]]
                return appearances?.contains { $0["appearance"] == "luminosity" && $0["value"] == "dark" } == true
            }
        )

        #expect(colorSpace(in: anyAppearance) == "display-p3")
        #expect(components(in: anyAppearance) == ["red": "1.000", "green": "0.604", "blue": "0.331", "alpha": "1.000"])
        #expect(colorSpace(in: darkAppearance) == "srgb")
        #expect(components(in: darkAppearance) == ["red": "0.967", "green": "0.434", "blue": "0.040", "alpha": "1.000"])
    }

    private func loadAsset(named name: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backword/Resources/Assets.xcassets/\(name).colorset/Contents.json")
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func components(in entry: [String: Any]) -> [String: String]? {
        let color = entry["color"] as? [String: Any]
        return color?["components"] as? [String: String]
    }

    private func colorSpace(in entry: [String: Any]) -> String? {
        let color = entry["color"] as? [String: Any]
        return color?["color-space"] as? String
    }
}
