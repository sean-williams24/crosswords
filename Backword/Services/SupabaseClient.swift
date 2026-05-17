//  SupabaseClient.swift

import Foundation
import Supabase

protocol SupabaseClientProtocol {
    func fetchFromSupabase() async throws -> BackwordWord
}

final class SupabaseClient: SupabaseClientProtocol {
    static let shared = SupabaseClient()
    private let dateFormatting = DateFormatting()
    private let client: Supabase.SupabaseClient

    init() {
        // Initialize the official client
        let url = URL(string: "https://cmvzqtpvzobdnnjpvyfi.supabase.co")!
        let key = "sb_publishable_Kj4RZqeTrOAXeOhRVdluVA_EFEOGveT"
        self.client = Supabase.SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    func fetchFromSupabase() async throws -> BackwordWord {
        let row: BackwordRow = try await client
            .from("backword_words")
            .select()
            .eq("date", value: today)
            .single()
            .execute()
            .value

        return row.toBackwordWord
    }

    func fetchArchive() async throws -> [BackwordWord] {
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
