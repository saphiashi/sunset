import Foundation

/// The first, gut-feel bucket for a sunset. Each tier owns a slice of the
/// 1–10 scale; position inside the tier decides the exact score.
enum RankTier: Int, CaseIterable, Comparable, Sendable {
    case okay = 0
    case lovely = 1
    case unforgettable = 2

    var title: String {
        switch self {
        case .unforgettable: return "Unforgettable"
        case .lovely: return "Lovely"
        case .okay: return "Just okay"
        }
    }

    var whisper: String {
        switch self {
        case .unforgettable: return "You’ll still talk about it"
        case .lovely: return "Glad you looked up"
        case .okay: return "A sky, not a story"
        }
    }

    var symbol: String {
        switch self {
        case .unforgettable: return "sun.horizon.fill"
        case .lovely: return "sun.haze.fill"
        case .okay: return "cloud.sun"
        }
    }

    var scoreRange: ClosedRange<Double> {
        switch self {
        case .unforgettable: return 7.0...10.0
        case .lovely: return 4.0...6.9
        case .okay: return 1.0...3.9
        }
    }

    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Binary insertion by pairwise questions: "was the new sky better than this one?"
/// The ladder is ordered best-first; `insertionIndex` is where the new sky lands.
struct RankComparison: Equatable, Sendable {
    private(set) var low: Int
    private(set) var high: Int

    init(ladderCount: Int) {
        low = 0
        high = max(0, ladderCount)
    }

    var isComplete: Bool { low >= high }

    /// Index in the ladder to compare against next, or nil when placed.
    var probe: Int? {
        isComplete ? nil : (low + high) / 2
    }

    var insertionIndex: Int { low }

    /// Worst-case questions left.
    var remaining: Int {
        var span = high - low
        var count = 0
        while span > 0 {
            span /= 2
            count += 1
        }
        return count
    }

    mutating func answer(newIsBetter: Bool) {
        guard let probe else { return }
        if newIsBetter {
            high = probe
        } else {
            low = probe + 1
        }
    }

    /// "Too close to call" and "skip" both settle right where we are.
    mutating func settle() {
        guard let probe else { return }
        low = probe
        high = probe
    }
}

enum RankScore {
    /// Scores for a best-first ladder, spread evenly through the tier's range
    /// and rounded to one decimal.
    static func scores(count: Int, tier: RankTier) -> [Double] {
        guard count > 0 else { return [] }
        let range = tier.scoreRange
        let span = range.upperBound - range.lowerBound
        return (0..<count).map { index in
            let raw = range.upperBound - span * (Double(index) + 0.5) / Double(count)
            return (raw * 10).rounded() / 10
        }
    }
}
