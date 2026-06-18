import Foundation
import UIKit

struct FeedbackEmailContent: Equatable {
    static let supportRecipient = "backword.support@gmail.com"

    let recipient: String
    let subject: String
    let body: String

    static var current: FeedbackEmailContent {
        FeedbackEmailContent(
            appVersion: .current,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model
        )
    }

    init(
        recipient: String = Self.supportRecipient,
        subject: String = "Backword Feedback",
        appVersion: AppVersionInfo,
        systemName: String,
        systemVersion: String,
        deviceModel: String
    ) {
        self.recipient = recipient
        self.subject = subject
        self.body = """
        Please describe the issue:


        ---
        App: Backword
        \(appVersion.displayText)
        OS: \(systemName) \(systemVersion)
        Device: \(deviceModel)
        """
    }

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
