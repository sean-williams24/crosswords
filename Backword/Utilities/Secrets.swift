//  Secrets.swift

import Foundation

enum Secrets {
    static var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String else {
            fatalError("SupabaseURL missing from Info.plist")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String else {
            fatalError("SupabaseAnonKey missing from Info.plist")
        }
        return key
    }

    static var googleIOSClientID: String {
        requiredString(forInfoDictionaryKey: "GoogleIOSClientID")
    }

    static var googleWebClientID: String {
        requiredString(forInfoDictionaryKey: "GoogleWebClientID")
    }

    private static func requiredString(forInfoDictionaryKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("$(") else {
            fatalError("\(key) missing from Info.plist")
        }
        return value
    }
}
