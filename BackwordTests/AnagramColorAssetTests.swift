import Foundation
import Testing

@Suite("Anagram colour assets")
struct AnagramColorAssetTests {
    @Test("Anagram orange uses the light orange by default and the deeper orange in dark mode")
    func anagramOrangeAppearances() throws {
        let asset = try #require(loadAsset()["colors"] as? [[String: Any]])
        let anyAppearance = try #require(asset.first)
        let darkAppearance = try #require(
            asset.first { entry in
                let appearances = entry["appearances"] as? [[String: String]]
                return appearances?.contains { $0["appearance"] == "luminosity" && $0["value"] == "dark" } == true
            }
        )

        #expect(components(in: anyAppearance) == ["red": "1.000", "green": "0.650", "blue": "0.360", "alpha": "1.000"])
        #expect(components(in: darkAppearance) == ["red": "0.967", "green": "0.434", "blue": "0.040", "alpha": "1.000"])
    }

    private func loadAsset() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backword/Resources/Assets.xcassets/AnagramOrange.colorset/Contents.json")
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func components(in entry: [String: Any]) -> [String: String]? {
        let color = entry["color"] as? [String: Any]
        return color?["components"] as? [String: String]
    }
}
