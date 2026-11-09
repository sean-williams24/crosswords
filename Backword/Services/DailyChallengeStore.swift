import Foundation

protocol DailyChallengeProgressLoading {
    func load(date: String, dailyPuzzle: Puzzle?) -> DailyChallengeSnapshot
}

struct DailyChallengeProgressStore: DailyChallengeProgressLoading {
    func load(date: String, dailyPuzzle: Puzzle?) -> DailyChallengeSnapshot {
        let crosswords: [UserProgress]
        if let dailyPuzzle, dailyPuzzle.date == date {
            crosswords = UserProgress.load(puzzleId: dailyPuzzle.id).map { [$0] } ?? []
        } else {
            crosswords = UserProgress.loadAll()
        }
        return DailyChallengeSnapshot(
            date: date, backword: BackwordProgress.load(date: date),
            crosswords: crosswords, dailyPuzzle: dailyPuzzle,
            anagram: AnagramProgress.load(date: date), midword: MidwordProgress.load(date: date)
        )
    }
}

protocol DailyChallengeCelebrationStoring {
    func contains(date: String, accountID: String?) -> Bool
    func acknowledge(date: String, accountID: String?)
    #if DEBUG
    func resetAcknowledgement(date: String, accountID: String?)
    #endif
}

struct DailyChallengeCelebrationStore: DailyChallengeCelebrationStoring {
    var defaults: UserDefaults = .standard

    func contains(date: String, accountID: String?) -> Bool {
        defaults.bool(forKey: key(date: date, accountID: accountID))
    }

    func acknowledge(date: String, accountID: String?) {
        defaults.set(true, forKey: key(date: date, accountID: accountID))
    }

    #if DEBUG
    func resetAcknowledgement(date: String, accountID: String?) {
        defaults.removeObject(forKey: key(date: date, accountID: accountID))
    }
    #endif

    private func key(date: String, accountID: String?) -> String {
        let namespace = accountID.map { "account:\($0)" } ?? "guest"
        return "home.dailyChallenge.celebrated.\(namespace).\(date)"
    }
}
