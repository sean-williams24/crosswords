//  PuzzleStatus.swift

import SwiftUI

enum PuzzleStatus {
    case completedOnTime
    case completedLate
    case wonBackword(Int)
    case failedBackword
    case inProgress
    case notStarted

    var icon: String {
        switch self {
        case .completedOnTime: return "checkmark.circle.fill"
        case .completedLate:   return "checkmark.circle.fill"
        case .wonBackword:     return "checkmark.circle.fill"
        case .failedBackword:  return "xmark.circle.fill"
        case .inProgress:      return "pencil.circle"
        case .notStarted:      return "circle"
        }
    }

    var label: String {
        switch self {
        case .completedOnTime:         return "Solved"
        case .completedLate:           return "Finished"
        case .wonBackword(let count):  return "\(count) guess\(count == 1 ? "" : "es")"
        case .failedBackword:          return "Failed"
        case .inProgress:              return "In Progress"
        case .notStarted:              return "New"
        }
    }

    var color: Color {
        switch self {
        case .completedOnTime: return .appCorrect
        case .completedLate:   return .appCorrect
        case .wonBackword:     return .appCorrect
        case .failedBackword:  return .red.opacity(0.7)
        case .inProgress:      return .appAccent
        case .notStarted:      return .appTextPrimary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .failedBackword: return .red.opacity(0.08)
        case .notStarted:     return color.opacity(0.08)
        default:              return color.opacity(0.12)
        }
    }

    static func status(for entry: ArchiveEntry) -> PuzzleStatus {
        guard let progress = UserProgress.load(puzzleId: entry.id) else {
            return .notStarted
        }
        guard progress.isComplete, let completedAt = progress.completedAt else {
            return .inProgress
        }
        return ContentReleaseCalendar(now: completedAt).dailyDateString == entry.date ? .completedOnTime : .completedLate
    }

    static func status(for progress: BackwordProgress?) -> PuzzleStatus {
        guard let progress else { return .notStarted }
        if progress.isComplete {
            return progress.isWon ? .wonBackword(progress.guesses.count) : .failedBackword
        }
        return progress.guesses.isEmpty ? .notStarted : .inProgress
    }
}
