import Foundation
import SwiftData

/// Applies `RankComparison` results to SwiftData: one best-first ladder per
/// tier, with `overallScore` derived from position.
@MainActor
enum RankBook {
    static func ladder(_ tier: RankTier, context: ModelContext, excluding id: UUID? = nil) -> [SunsetEntry] {
        let all = (try? context.fetch(FetchDescriptor<SunsetEntry>())) ?? []
        return all
            .filter { $0.isMine && $0.rankTier == tier.rawValue && $0.id != id }
            .sorted { ($0.rankOrder ?? .max) < ($1.rankOrder ?? .max) }
    }

    /// Every ranked sky of yours, best first across tiers.
    static func ranked(context: ModelContext) -> [SunsetEntry] {
        RankTier.allCases.reversed().flatMap { ladder($0, context: context) }
    }

    static func position(of entry: SunsetEntry, context: ModelContext) -> (rank: Int, total: Int)? {
        guard entry.tier != nil else { return nil }
        let all = ranked(context: context)
        guard let index = all.firstIndex(where: { $0.id == entry.id }) else { return nil }
        return (index + 1, all.count)
    }

    /// Moves `entry` (ranked or not) into `tier` at `index` and rescores both
    /// the destination ladder and the one it left.
    static func place(_ entry: SunsetEntry, tier: RankTier, at index: Int, context: ModelContext) {
        let previous = entry.tier
        var destination = ladder(tier, context: context, excluding: entry.id)
        destination.insert(entry, at: min(max(0, index), destination.count))
        renumber(destination, tier: tier)
        if let previous, previous != tier {
            renumber(ladder(previous, context: context), tier: previous)
        }
    }

    static func renumber(_ ladder: [SunsetEntry], tier: RankTier, markForSync: Bool = true) {
        let scores = RankScore.scores(count: ladder.count, tier: tier)
        for (index, entry) in ladder.enumerated() {
            let changed = entry.rankTier != tier.rawValue
                || entry.rankOrder != index
                || entry.overallScore != scores[index]
            guard changed else { continue }
            entry.rankTier = tier.rawValue
            entry.rankOrder = index
            entry.overallScore = scores[index]
            if markForSync { entry.needsSync = true }
        }
    }
}
