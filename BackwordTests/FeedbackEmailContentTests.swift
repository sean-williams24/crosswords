import Testing
@testable import Backword

@Suite("Feedback email content")
struct FeedbackEmailContentTests {
    @Test("Uses support recipient and standard subject")
    func supportRecipientAndSubject() {
        let content = makeContent()

        #expect(content.recipient == "backword.support@gmail.com")
        #expect(content.subject == "Backword Feedback")
    }

    @Test("Body includes issue prompt and diagnostics")
    func bodyIncludesPromptAndDiagnostics() {
        let content = makeContent()

        #expect(content.body.contains("Please describe the issue:"))
        #expect(content.body.contains("App: Backword"))
        #expect(content.body.contains("Version 1.2.3 (Build 45)"))
        #expect(content.body.contains("OS: iOS 18.0"))
        #expect(content.body.contains("Device: iPhone"))
    }

    @Test("Mailto URL encodes subject and body")
    func mailtoURLEncoding() throws {
        let content = makeContent()
        let url = try #require(content.mailtoURL)
        let urlString = url.absoluteString

        #expect(url.scheme == "mailto")
        #expect(urlString.contains("backword.support@gmail.com"))
        #expect(urlString.contains("subject=Backword%20Feedback"))
        #expect(urlString.contains("body="))
        #expect(urlString.contains("Please%20describe%20the%20issue"))
        #expect(!urlString.contains(" "))
    }

    private func makeContent() -> FeedbackEmailContent {
        FeedbackEmailContent(
            appVersion: AppVersionInfo(version: "1.2.3", build: "45"),
            systemName: "iOS",
            systemVersion: "18.0",
            deviceModel: "iPhone"
        )
    }
}
