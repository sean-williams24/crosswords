import Foundation

struct AppVersionInfo: Equatable {
    let version: String?
    let build: String?

    static var current: AppVersionInfo {
        AppVersionInfo(bundle: .main)
    }

    init(version: String?, build: String?) {
        self.version = Self.normalized(version)
        self.build = Self.normalized(build)
    }

    init(bundle: Bundle) {
        self.init(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    var displayText: String {
        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (Build \(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        case let (.none, .some(build)):
            return "Build \(build)"
        case (.none, .none):
            return "Version unavailable"
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }

        return value
    }
}
