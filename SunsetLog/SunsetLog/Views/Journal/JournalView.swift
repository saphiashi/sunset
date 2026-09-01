import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(Router.self) private var router
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]
    @State private var showMineOnly = true

    private var visible: [SunsetEntry] {
        entries.filter { showMineOnly ? $0.isMine : true }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                journalHeader
                Picker("Filter", selection: $showMineOnly) {
                    Text("Yours").tag(true)
                    Text("Circle").tag(false)
                }
                .pickerStyle(.segmented)
                journalList
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var journalHeader: some View {
        HStack {
            SectionHeader(eyebrow: "Evenings kept", title: "Journal")
            Spacer()
            Button {
                router.open(.calendar, in: .journal)
            } label: {
                Image(systemName: "calendar")
                    .font(.title3)
            }
            .accessibilityLabel("Calendar")
        }
    }

    @ViewBuilder
    private var journalList: some View {
        if visible.isEmpty {
            QuietEmpty(
                symbol: "moon.stars",
                title: "A blank month",
                detail: showMineOnly
                    ? "Your own evenings will live here."
                    : "Follow someone, then their skies appear."
            )
        } else {
            ForEach(visible, id: \.id) { entry in
                NavigationLink(value: Route.entry(entry.id)) {
                    EntryCard(entry: entry, compact: false)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EntryCard: View {
    let entry: SunsetEntry
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkyPhoto(entry: entry, corner: 20)
                .frame(height: compact ? 210 : 280)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.spot?.name ?? "An unmarked sky")
                        .font(Typeface.display(22))
                    Text(meta)
                        .font(Typeface.caption(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(ScoreFormat.oneDecimal(entry.overallScore))
                    .font(Typeface.display(28))
                    .foregroundStyle(Palette.ember)
            }
            if !entry.note.isEmpty && !compact {
                Text(entry.note)
                    .font(Typeface.body(15))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(3)
            }
        }
    }

    private var meta: String {
        let day = entry.capturedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        if entry.isMine {
            return day
        }
        return "\(entry.authorName) · \(day)"
    }
}

struct EntryDetailView: View {
    let entryID: UUID
    @Query private var entries: [SunsetEntry]
    @Query private var collections: [SkyCollection]

    var body: some View {
        Group {
            if let entry = entries.first(where: { $0.id == entryID }) {
                EntryDetailLoaded(entry: entry, collections: collections)
            } else {
                QuietEmpty(symbol: "photo", title: "This evening left", detail: "The entry is no longer in the journal.")
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EntryDetailLoaded: View {
    let entry: SunsetEntry
    let collections: [SkyCollection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SkyPhoto(entry: entry, corner: 26)
                    .frame(height: 420)
                EntryDetailHeader(entry: entry)
                ScorePills(color: entry.colorScore, drama: entry.dramaScore, overall: entry.overallScore)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(Typeface.body(17))
                        .lineSpacing(4)
                }
                if let spot = entry.spot {
                    NavigationLink(value: Route.spot(spot.id)) {
                        Label("Open \(spot.name)", systemImage: "mappin.and.ellipse")
                            .font(Typeface.body(16, weight: .semibold))
                    }
                }
                if entry.isMine {
                    CollectionMembershipEditor(entry: entry, collections: collections)
                }
            }
            .padding(20)
        }
    }
}

private struct EntryDetailHeader: View {
    let entry: SunsetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.spot?.name ?? "An unmarked sky")
                .font(Typeface.display(34))
            Text(whenLine)
                .foregroundStyle(.secondary)
            if !entry.isMine {
                Text("Logged by \(entry.authorName)")
                    .font(Typeface.caption(13))
                    .foregroundStyle(Palette.ember)
            }
            if entry.importedFromLibrary {
                Text("Imported from the camera roll")
                    .font(Typeface.caption(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var whenLine: String {
        entry.capturedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())
    }
}

private struct CollectionMembershipEditor: View {
    let entry: SunsetEntry
    let collections: [SkyCollection]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collections")
                .font(Typeface.display(22))
            ForEach(collections, id: \.id) { collection in
                CollectionMembershipRow(entry: entry, collection: collection)
            }
        }
        .padding(.top, 8)
    }
}

private struct CollectionMembershipRow: View {
    @Environment(\.modelContext) private var context
    let entry: SunsetEntry
    let collection: SkyCollection

    private var belongs: Bool {
        entry.collections.contains { $0.id == collection.id }
    }

    var body: some View {
        Button(action: toggle) {
            HStack {
                Image(systemName: collection.symbol)
                    .foregroundStyle(collection.accent)
                Text(collection.name)
                Spacer()
                Image(systemName: belongs ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(belongs ? Palette.ember : Color.secondary.opacity(0.45))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        if belongs {
            collection.entries.removeAll { $0.id == entry.id }
        } else {
            collection.entries.append(entry)
        }
        try? context.save()
    }
}
