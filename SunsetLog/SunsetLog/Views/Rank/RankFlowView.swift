import SwiftUI
import SwiftData

struct RankTarget: Identifiable, Hashable {
    let id: UUID
}

/// Tier first, then "which sky stayed with you?" until the new evening finds its place.
struct RankFlowView: View {
    let entryID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Query private var entries: [SunsetEntry]

    @State private var tier: RankTier?
    @State private var ladder: [SunsetEntry] = []
    @State private var comparison = RankComparison(ladderCount: 0)
    @State private var placement: Placement?

    private struct Placement: Equatable {
        let rank: Int
        let total: Int
    }

    private var entry: SunsetEntry? {
        entries.first { $0.id == entryID }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                content
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .duskBackdrop()
            .navigationTitle("Rank it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(placement == nil ? "Later" : "Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry {
            if let placement {
                doneStep(entry, placement)
            } else if let tier, let probe = comparison.probe, ladder.indices.contains(probe) {
                compareStep(entry, against: ladder[probe], rank: probe + 1, tier: tier)
            } else {
                tierStep(entry)
            }
        } else {
            QuietEmpty(symbol: "photo", title: "This evening left", detail: "The entry is no longer in the journal.")
        }
    }

    // MARK: - Steps

    private func tierStep(_ entry: SunsetEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SkyPhoto(entry: entry, corner: 22)
                .frame(height: 220)
            Text("How did it feel?")
                .font(Typeface.italic(30))
            Text("Pick a feeling, then we’ll compare it with your other evenings.")
                .font(Typeface.body(15))
                .foregroundStyle(.secondary)
            ForEach(RankTier.allCases.reversed(), id: \.self) { option in
                TierButton(tier: option, isCurrent: entry.tier == option) {
                    choose(option)
                }
            }
        }
    }

    private func compareStep(_ entry: SunsetEntry, against other: SunsetEntry, rank: Int, tier: RankTier) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Which sky stayed with you?")
                    .font(Typeface.italic(26))
                    .multilineTextAlignment(.center)
                Text(comparison.remaining <= 1 ? "Last question" : "About \(comparison.remaining) more")
                    .font(Typeface.caption(12))
                    .foregroundStyle(.secondary)
            }
            RankChoiceCard(entry: entry, label: "This evening") {
                answer(newIsBetter: true)
            }
            Text("or")
                .font(Typeface.italic(16))
                .foregroundStyle(.secondary)
            RankChoiceCard(entry: other, label: "\(tier.title) · #\(rank)") {
                answer(newIsBetter: false)
            }
            Button("Too close to call") {
                comparison.settle()
                finish()
            }
            .font(Typeface.body(15, weight: .semibold))
            .foregroundStyle(Palette.ember)
            .padding(.top, 4)
        }
        .id(other.id)
        .transition(.opacity)
    }

    private func doneStep(_ entry: SunsetEntry, _ placement: Placement) -> some View {
        VStack(spacing: 18) {
            SkyPhoto(entry: entry, corner: 22)
                .frame(height: 260)
            Text("#\(placement.rank)")
                .font(Typeface.display(72))
            Text(placement.total == 1
                 ? "Your first ranked evening"
                 : "of \(placement.total) evenings you’ve ranked")
                .font(Typeface.italic(20))
                .foregroundStyle(.secondary)
            Text("\(entry.tier?.title ?? "") · \(ScoreFormat.oneDecimal(entry.overallScore))")
                .font(Typeface.body(17, weight: .semibold))
                .foregroundStyle(Palette.ember)
            EmberButton(title: "See your ranking", systemImage: "list.number") {
                dismiss()
                router.open(.rankings, in: .journal)
            }
            .padding(.top, 8)
            EmberButton(title: "Done", fill: false) {
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func choose(_ option: RankTier) {
        tier = option
        ladder = RankBook.ladder(option, context: context, excluding: entryID)
        comparison = RankComparison(ladderCount: ladder.count)
        if comparison.isComplete {
            finish()
        }
    }

    private func answer(newIsBetter: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            comparison.answer(newIsBetter: newIsBetter)
        }
        if comparison.isComplete {
            finish()
        }
    }

    private func finish() {
        guard let entry, let tier else { return }
        RankBook.place(entry, tier: tier, at: comparison.insertionIndex, context: context)
        try? context.save()
        session.cloud.schedule()
        if let position = RankBook.position(of: entry, context: context) {
            withAnimation { placement = Placement(rank: position.rank, total: position.total) }
        } else {
            dismiss()
        }
    }
}

private struct TierButton: View {
    let tier: RankTier
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: tier.symbol)
                    .font(.title2)
                    .foregroundStyle(Palette.gold)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.title)
                        .font(Typeface.italic(22))
                    Text(tier.whisper)
                        .font(Typeface.caption(13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isCurrent ? Palette.ember : Color.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RankChoiceCard: View {
    let entry: SunsetEntry
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SkyPhoto(entry: entry, corner: 22)
                .frame(height: 210)
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label.uppercased())
                            .font(Typeface.caption(10))
                            .tracking(2)
                            .foregroundStyle(Palette.gold)
                        Text(entry.spot?.name ?? "Somewhere west")
                            .font(Typeface.italic(22))
                        Text(entry.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                            .font(Typeface.caption(12))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(entry.spot?.name ?? "Somewhere west")")
    }
}
