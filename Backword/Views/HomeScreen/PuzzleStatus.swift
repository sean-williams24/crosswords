//  PuzzleStatus.swift

import SwiftUI

enum PuzzleStatus {
    case new
    case inProgress
    case completed(String)

    var label: String {
        switch self {
        case .new: return "NEW"
        case .inProgress: return "In Progress..."
        case .completed(let time): return "Completed in \(time)"
        }
    }

    var icon: String {
        switch self {
        case .new: return "plus.circle.fill"
        case .inProgress: return "pencil.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .new: return .appAccent
        case .inProgress: return .appAccent
        case .completed: return .appCorrect
        }
    }
}
