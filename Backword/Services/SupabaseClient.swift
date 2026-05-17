//  SupabaseClient.swift

import Foundation
import Supabase

protocol SupabaseClientProtocol {
    func fetchTodaysBackword() async throws -> BackwordWord
    func fetchBackwordArchive() async throws -> [BackwordWord]
}

final class SupabaseClient: SupabaseClientProtocol {
    static let shared = SupabaseClient()
    private let dateFormatting = DateFormatting()
    private let client: Supabase.SupabaseClient
    private let baseURL = "https://cmvzqtpvzobdnnjpvyfi.supabase.co"
    private let apiKey = "sb_publishable_Kj4RZqeTrOAXeOhRVdluVA_EFEOGveT"

    init() {
        self.client = Supabase.SupabaseClient(supabaseURL: URL(string: baseURL)!, supabaseKey: apiKey)
    }

    func fetchTodaysBackword() async throws -> BackwordWord {
        let row: BackwordRow = try await client
            .from("backword_words")
            .select()
            .eq("date", value: today)
            .single()
            .execute()
            .value

        return row.toBackwordWord
    }

    func fetchBackwordArchive() async throws -> [BackwordWord] {
        let rows: [BackwordRow] = try await client
            .from("backword_words")
            .select()
            .lte("date", value: today)       // Equivalent to date=lte.\(today)
            .order("date", ascending: false) // Equivalent to order=date.desc
            .limit(90)                       // Equivalent to limit=90
            .execute()
            .value

        return rows.map { $0.toBackwordWord }
    }

    private var today: String {
        dateFormatting.todayString()
    }
}
