//  SupabaseClient.swift

import Foundation
import Supabase

protocol SupabaseClientProtocol {
    func fetchTodaysBackword() async throws -> BackwordWord
    func fetchBackwordArchive() async throws -> [BackwordWord]
    func fetchBackwordArchiveMonths() async throws -> [ArchiveMonth]
    func fetchBackwords(for month: ArchiveMonth) async throws -> [BackwordWord]
}

final class SupabaseClient: SupabaseClientProtocol {
    static let shared = SupabaseClient()
    private let dateFormatting = DateFormatting()
    private let client: Supabase.SupabaseClient
    private let baseURL = Secrets.supabaseURL
    private let apiKey = Secrets.supabaseAnonKey

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

    func fetchBackwordArchiveMonths() async throws -> [ArchiveMonth] {
        let rows: [BackwordDateRow] = try await client
            .from("backword_words")
            .select("date")
            .lte("date", value: today)
            .order("date", ascending: false)
            .execute()
            .value

        return Array(Set(rows.compactMap { ArchiveMonth.from(dateString: $0.date) })).sorted(by: >)
    }

    func fetchBackwords(for month: ArchiveMonth) async throws -> [BackwordWord] {
        let range = month.dateRange()
        let upperBound = min(range.upperBound, today)
        guard range.lowerBound <= upperBound else { return [] }

        let rows: [BackwordRow] = try await client
            .from("backword_words")
            .select()
            .gte("date", value: range.lowerBound)
            .lte("date", value: upperBound)
            .order("date", ascending: false)
            .execute()
            .value

        return rows.map { $0.toBackwordWord }
    }

    private var today: String {
        dateFormatting.todayString()
    }
}

private struct BackwordDateRow: Decodable {
    let date: String
}
