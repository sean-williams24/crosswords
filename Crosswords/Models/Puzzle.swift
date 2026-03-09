import Foundation

// MARK: - Direction

enum Direction: String, Codable, CaseIterable {
    case across
    case down
}

// MARK: - Clue

struct Clue: Codable, Identifiable, Equatable {
    let id: Int
    let direction: Direction
    let number: Int
    let text: String
    let hint: String
    let answer: String
    let startRow: Int
    let startCol: Int
    let length: Int

    var cells: [(row: Int, col: Int)] {
        (0..<length).map { offset in
            switch direction {
            case .across: return (startRow, startCol + offset)
            case .down:   return (startRow + offset, startCol)
            }
        }
    }

    static func == (lhs: Clue, rhs: Clue) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CellData

struct CellData: Codable {
    let letter: String?
    let clueNumber: Int?
    let acrossClueId: Int?
    let downClueId: Int?

    var isBlack: Bool { letter == nil }

    var character: Character? {
        letter.flatMap(\.first)
    }
}

// MARK: - Puzzle

struct Puzzle: Codable, Identifiable, Hashable {
    let id: String
    let puzzleNumber: Int
    let date: String
    let size: Int
    let cells: [[CellData]]
    let clues: [Clue]

    static func == (lhs: Puzzle, rhs: Puzzle) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var acrossClues: [Clue] {
        clues.filter { $0.direction == .across }.sorted { $0.number < $1.number }
    }

    var downClues: [Clue] {
        clues.filter { $0.direction == .down }.sorted { $0.number < $1.number }
    }

    func clue(for id: Int) -> Clue? {
        clues.first { $0.id == id }
    }

    func cluesAt(row: Int, col: Int) -> (across: Clue?, down: Clue?) {
        let cell = cells[row][col]
        return (
            across: cell.acrossClueId.flatMap { clue(for: $0) },
            down: cell.downClueId.flatMap { clue(for: $0) }
        )
    }
}

// MARK: - Sample Data

extension Puzzle {
    static let sample: Puzzle = {
        // A simple 9x9 crossword for development
        let size = 9

        // Define the grid: nil letter = black square
        // Using a simple symmetric pattern
        let pattern: [[String?]] = [
            ["S", "T", "A", "R", nil, "M", "A", "P", "S"],
            ["H", nil, nil, "A", nil, "A", nil, "L", nil],
            ["E", "A", "R", "I", "N", "G", nil, "A", nil],
            ["D", nil, nil, "N", nil, "I", nil, "N", nil],
            [nil, nil, "J", "E", "S", "C", nil, nil, nil],
            [nil, nil, nil, "D", nil, nil, nil, nil, nil],
            [nil, "C", nil, nil, nil, "S", "U", "N", "S"],
            [nil, "A", nil, "W", "I", "N", "D", nil, nil],
            ["B", "T", "S", nil, nil, nil, "E", nil, nil],
        ]

        var cells: [[CellData]] = []
        var clueNumber = 1
        var clueList: [Clue] = []

        for row in 0..<size {
            var rowCells: [CellData] = []
            for col in 0..<size {
                let letter = pattern[row][col]
                var number: Int? = nil

                if letter != nil {
                    let needsAcross = (col == 0 || pattern[row][col - 1] == nil) &&
                                      col + 1 < size && pattern[row][col + 1] != nil
                    let needsDown = (row == 0 || pattern[row - 1][col] == nil) &&
                                    row + 1 < size && pattern[row + 1][col] != nil

                    if needsAcross || needsDown {
                        number = clueNumber
                        clueNumber += 1
                    }
                }

                rowCells.append(CellData(
                    letter: letter,
                    clueNumber: number,
                    acrossClueId: nil,
                    downClueId: nil
                ))
            }
            cells.append(rowCells)
        }

        // Build clues from the pattern
        clueNumber = 1
        var clueId = 0
        var acrossIds: [[Int?]] = Array(repeating: Array(repeating: nil, count: size), count: size)
        var downIds: [[Int?]] = Array(repeating: Array(repeating: nil, count: size), count: size)

        for row in 0..<size {
            for col in 0..<size {
                guard pattern[row][col] != nil else { continue }

                let needsAcross = (col == 0 || pattern[row][col - 1] == nil) &&
                                  col + 1 < size && pattern[row][col + 1] != nil
                let needsDown = (row == 0 || pattern[row - 1][col] == nil) &&
                                row + 1 < size && pattern[row + 1][col] != nil

                let hasNumber = needsAcross || needsDown

                if needsAcross {
                    var length = 0
                    var word = ""
                    var c = col
                    while c < size, let letter = pattern[row][c] {
                        word += letter
                        length += 1
                        c += 1
                    }
                    let clue = Clue(
                        id: clueId, direction: .across, number: clueNumber,
                        text: sampleClueText(for: word),
                        hint: sampleHintText(for: word),
                        answer: word,
                        startRow: row, startCol: col, length: length
                    )
                    clueList.append(clue)
                    for i in 0..<length {
                        acrossIds[row][col + i] = clueId
                    }
                    clueId += 1
                }

                if needsDown {
                    var length = 0
                    var word = ""
                    var r = row
                    while r < size, let letter = pattern[r][col] {
                        word += letter
                        length += 1
                        r += 1
                    }
                    let clue = Clue(
                        id: clueId, direction: .down, number: clueNumber,
                        text: sampleClueText(for: word),
                        hint: sampleHintText(for: word),
                        answer: word,
                        startRow: row, startCol: col, length: length
                    )
                    clueList.append(clue)
                    for i in 0..<length {
                        downIds[row + i][col] = clueId
                    }
                    clueId += 1
                }

                if hasNumber {
                    clueNumber += 1
                }
            }
        }

        // Rebuild cells with clue IDs
        var finalCells: [[CellData]] = []
        for row in 0..<size {
            var rowCells: [CellData] = []
            for col in 0..<size {
                let old = cells[row][col]
                rowCells.append(CellData(
                    letter: old.letter,
                    clueNumber: old.clueNumber,
                    acrossClueId: acrossIds[row][col],
                    downClueId: downIds[row][col]
                ))
            }
            finalCells.append(rowCells)
        }

        return Puzzle(
            id: "sample-001",
            puzzleNumber: 1,
            date: "2026-03-07",
            size: size,
            cells: finalCells,
            clues: clueList
        )
    }()

    private static func sampleClueText(for word: String) -> String {
        let clues: [String: String] = [
            "STAR": "Celestial body visible at night",
            "MAPS": "Navigation aids",
            "SHED": "Garden storage building",
            "EARING": "Nautical rope on a sail",
            "MAGIC": "Tricks and illusions",
            "PLAN": "Strategy or scheme",
            "RAINED": "Past tense of precipitate",
            "JES": "Affirmative replies (archaic)",
            "SUNS": "Stars at center of solar systems",
            "WIND": "Moving air current",
            "CAT": "Feline companion",
            "BTS": "K-pop supergroup",
            "UDE": "German city suffix",
        ]
        return clues[word] ?? "A word (\(word.count) letters)"
    }

    private static func sampleHintText(for word: String) -> String {
        let hints: [String: String] = [
            "STAR": "Hollywood celebrity",
            "MAPS": "What Google or Apple help you with",
            "SHED": "Where you keep a lawnmower",
            "EARING": "Securing a reef in a sail",
            "MAGIC": "What a wizard does",
            "PLAN": "What you make before a trip",
            "RAINED": "What the clouds did yesterday",
            "JES": "Old way of saying yes",
            "SUNS": "Phoenix NBA team",
            "WIND": "What makes a flag wave",
            "CAT": "Meowing pet",
            "BTS": "Bangtan Boys",
            "UDE": "Suffix meaning town",
        ]
        return hints[word] ?? "Think about it differently..."
    }
}
