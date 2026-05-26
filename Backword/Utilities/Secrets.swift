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
}
