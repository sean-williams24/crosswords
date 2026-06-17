import Testing
@testable import Backword

@Suite("App version info")
struct AppVersionInfoTests {
    @Test("Display text includes version and build")
    func displayTextIncludesVersionAndBuild() {
        let info = AppVersionInfo(version: "1.2.3", build: "45")

        #expect(info.displayText == "Version 1.2.3 (Build 45)")
    }

    @Test("Display text falls back to version when build is missing")
    func displayTextFallsBackToVersion() {
        let info = AppVersionInfo(version: "1.2.3", build: nil)

        #expect(info.displayText == "Version 1.2.3")
    }

    @Test("Display text falls back to build when version is missing")
    func displayTextFallsBackToBuild() {
        let info = AppVersionInfo(version: nil, build: "45")

        #expect(info.displayText == "Build 45")
    }

    @Test("Blank values are treated as unavailable")
    func blankValuesAreUnavailable() {
        let info = AppVersionInfo(version: " ", build: "\n")

        #expect(info.displayText == "Version unavailable")
    }
}
