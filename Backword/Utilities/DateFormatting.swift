//
//  DateFormatting.swift
//  Backword
//
//  Created by Sean Williams on 04/05/2026.
//

import Foundation

final class DateFormatting {
    func todayString() -> String {
        formatter.string(from: Date())
    }

    var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: Date()).capitalized
    }
}
