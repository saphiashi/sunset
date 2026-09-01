import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(Router.self) private var router
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]
    @State private var showMineOnly = true

    var body: some View {
        let visible = entries.filter { showMineOnly ? $0.isMine : true }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

                Picker("Filter", selection: $showMineOnly) {
                    Text("Yours").tag(true)
                    Text("Circle").tag(false)
                }
                .pickerStyle(.segmented)

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
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
    @Environment(\.modelContext) private var context

    private var entry: SunsetEntry? { entries.first { $0.id == entryID } }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SkyPhoto(entry: entry, corner: 26)
                            .frame(height: 420)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.spot?.name ?? "An unmarked sky")
                                .font(Typeface.display(34))
                            Text(entry.capturedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
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
                            collectionEditor(entry)
                        }
                    }
                    .padding(20)
                }
            } else {
                QuietEmpty(symbol: "photo", title: "This evening left", detail: "The entry is no longer in the journal.")
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func collectionEditor(_ entry: SunsetEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collections")
                .font(Typeface.display(22))
            ForEach(collections, id: \.id) { collection in
                let belongs = entry.collections.contains(where: { $0.id == collection.id })
                Button {
                    if belongs {
                        collection.entries.removeAll { $0.id == entry.id }
                    } else {
                        collection.entries.append(entry)
                    }
                    try? context.save()
                } label: {
                    HStack {
                        Image(systemName: collection.symbol)
                            .foregroundStyle(collection.accent)
                        Text(collection.name)
                        Spacer()
                        Image(systemName: belongs ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(belongs ? Palette.ember : .tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}
