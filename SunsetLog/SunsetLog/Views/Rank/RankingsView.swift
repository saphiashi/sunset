import SwiftUI
import SwiftData

/// Your skies, best first. Unranked evenings wait below with a shortcut to rank them.
struct RankingsView: View {
    @Environment(AppSession.self) private var session
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]

    private var ranked: [SunsetEntry] {
        entries
            .filter { $0.isMine && $0.tier != nil }
            .sorted {
                if $0.rankTier != $1.rankTier {
                    return ($0.rankTier ?? 0) > ($1.rankTier ?? 0)
                }
                return ($0.rankOrder ?? .max) < ($1.rankOrder ?? .max)
            }
    }

    private var unranked: [SunsetEntry] {
        entries.filter { $0.isMine && $0.tier == nil }
    }

    var body: some View {
        let ranked = self.ranked
        let unranked = self.unranked
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    eyebrow: "Best first",
                    title: "Your ranking",
                    accessory: ranked.isEmpty ? nil : "\(ranked.count) skies"
                )
                if ranked.isEmpty && unranked.isEmpty {
                    QuietEmpty(
                        symbol: "list.number",
                        title: "Nothing ranked yet",
                        detail: "Log a sunset and we’ll ask how it compares.",
                        actionTitle: "Log tonight"
                    ) {
                        session.logPresented = true
                    }
                }
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, entry in
                    if index == 0 || ranked[index - 1].rankTier != entry.rankTier, let tier = entry.tier {
                        tierLabel(tier)
                    }
                    NavigationLink(value: Route.entry(entry.id)) {
                        RankRow(rank: index + 1, entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                if !unranked.isEmpty {
                    SectionHeader(eyebrow: "Waiting", title: "Not ranked yet")
                        .padding(.top, 18)
                    ForEach(unranked, id: \.id) { entry in
                        UnrankedRow(entry: entry) {
                            session.rankingEntry = RankTarget(id: entry.id)
                        }
                    }
                }
            }
            .padding(20)
        }
        .duskBackdrop()
        .navigationTitle("Ranking")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tierLabel(_ tier: RankTier) -> some View {
        Label(tier.title, systemImage: tier.symbol)
            .font(Typeface.caption(12))
            .tracking(1.6)
            .foregroundStyle(Palette.gold)
            .padding(.top, 10)
    }
}

private struct RankRow: View {
    let rank: Int
    let entry: SunsetEntry

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(Typeface.display(26))
                .frame(width: 36)
            SkyPhoto(entry: entry, corner: 14)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.spot?.name ?? "Somewhere west")
                    .font(Typeface.italic(19))
                    .lineLimit(1)
                Text(entry.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(Typeface.caption(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(ScoreFormat.oneDecimal(entry.overallScore))
                .font(Typeface.body(17, weight: .semibold))
                .foregroundStyle(Palette.ember)
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct UnrankedRow: View {
    let entry: SunsetEntry
    let rank: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SkyPhoto(entry: entry, corner: 14)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.spot?.name ?? "Somewhere west")
                    .font(Typeface.italic(19))
                    .lineLimit(1)
                Text(entry.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(Typeface.caption(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Rank", action: rank)
                .font(Typeface.body(15, weight: .semibold))
                .foregroundStyle(Palette.ember)
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
