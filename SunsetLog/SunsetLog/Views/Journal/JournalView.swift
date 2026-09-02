import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(Router.self) private var router
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]
    @State private var showMineOnly = true
    @State private var expanded: ExpandedPhoto?

    private var visible: [SunsetEntry] {
        entries.filter { showMineOnly ? $0.isMine : true }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                journalHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                filterChips
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                journalList
            }
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .duskBackdrop()
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $expanded) { item in
            JournalLightbox(entryID: item.id) {
                expanded = nil
                router.open(.entry(item.id), in: .journal)
            }
            .presentationBackground(.black)
        }
    }

    private var journalHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EVENINGS KEPT")
                    .font(Typeface.caption(11))
                    .tracking(2.4)
                    .foregroundStyle(Palette.gold)
                Text("The journal")
                    .font(Typeface.italic(34))
            }
            Spacer()
            Button {
                router.open(.calendar, in: .journal)
            } label: {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(12)
                    .background(.ultraThinMaterial.opacity(0.5), in: Circle())
            }
            .accessibilityLabel("Calendar")
        }
    }

    private var filterChips: some View {
        HStack(spacing: 10) {
            JournalFilterChip(title: "Yours", isOn: showMineOnly) { showMineOnly = true }
            JournalFilterChip(title: "Circle", isOn: !showMineOnly) { showMineOnly = false }
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
            .padding(.top, 40)
        } else {
            JournalRibbon(entries: visible) { entry in
                expanded = ExpandedPhoto(id: entry.id)
            }
        }
    }
}

private struct JournalFilterChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.italic(16))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Color.white : Palette.dusk)
                .background {
                    Capsule()
                        .fill(isOn ? Palette.ember.opacity(0.85) : Color.white.opacity(0.28))
                }
        }
        .buttonStyle(.plain)
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
        .duskBackdrop()
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EntryDetailLoaded: View {
    let entry: SunsetEntry
    let collections: [SkyCollection]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero
                detailPanel
                    .offset(y: -48)
                    .padding(.bottom, -24)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            SkyPhoto(entry: entry, corner: 0)
                .frame(height: 520)
                .overlay { SkyGradient.veil }
            VeilCaption(entry: entry, compact: false)
                .padding(.horizontal, 22)
                .padding(.bottom, 64)
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(Typeface.italic(20))
                    .lineSpacing(5)
            }
            if let spot = entry.spot {
                NavigationLink(value: Route.spot(spot.id)) {
                    Label("Open \(spot.name)", systemImage: "mappin.and.ellipse")
                        .font(Typeface.body(16, weight: .semibold))
                        .foregroundStyle(Palette.ember)
                }
            }
            if entry.isMine {
                CollectionMembershipEditor(entry: entry, collections: collections)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.72), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
    }
}

private struct CollectionMembershipEditor: View {
    let entry: SunsetEntry
    let collections: [SkyCollection]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collections")
                .font(Typeface.italic(22))
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
