import SwiftUI
import SwiftData

struct CircleHomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]
    @Query(sort: \Person.displayName) private var people: [Person]
    @Query(sort: \SkyCollection.name) private var collections: [SkyCollection]
    @Query private var spots: [Spot]
    @Query private var notes: [SharedSpotNote]
    @State private var newCollection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                profile
                collectionsRow
                savedRow
                friends
                inbox
                feed
            }
            .padding(20)
        }
        .duskBackdrop()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    newCollection = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("New collection")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $newCollection) {
            NewCollectionSheet()
        }
    }

    private var me: Person? { people.first(where: \.isMe) }

    private var profile: some View {
        let days = AppSession.streak(from: entries, now: session.now)
        return HStack(spacing: 14) {
            PersonMark(name: me?.displayName ?? "You", hue: me?.avatarHue ?? 0.08, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(me?.displayName ?? "You")
                    .font(Typeface.display(28))
                Text("\(days) evenings in a row · @\(me?.handle ?? "you")")
                    .font(Typeface.caption(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var collectionsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: "Kept together", title: "Collections")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(collections, id: \.id) { collection in
                        NavigationLink(value: Route.collection(collection.id)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: collection.symbol)
                                    .foregroundStyle(collection.accent)
                                Text(collection.name)
                                    .font(Typeface.italic(20))
                                    .foregroundStyle(.primary)
                                Text("\(collection.entries.count) evenings")
                                    .font(Typeface.caption(12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(width: 168, alignment: .leading)
                            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var savedRow: some View {
        let saved = spots.filter(\.isSaved)
        return Button {
            router.open(.saved, in: .circle)
        } label: {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Palette.gold)
                Text("Saved spots")
                    .font(Typeface.body(16, weight: .semibold))
                Spacer()
                Text("\(saved.count)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var friends: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: "People who look up", title: "Circle")
            ForEach(people.filter { !$0.isMe }, id: \.id) { person in
                NavigationLink(value: Route.friend(person.id)) {
                    HStack(spacing: 12) {
                        PersonMark(name: person.displayName, hue: person.avatarHue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .font(Typeface.body(16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("\(person.city) · @\(person.handle)")
                                .font(Typeface.caption(12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(person.isFollowing ? "Following" : "Follow")
                            .font(Typeface.caption(12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(person.isFollowing ? Palette.ember.opacity(0.15) : Palette.card)
                            .foregroundStyle(Palette.ember)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var inbox: some View {
        let incoming = notes.filter { $0.toHandle == "you" }
        return Group {
            if !incoming.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared with you")
                        .font(Typeface.display(22))
                    ForEach(incoming, id: \.id) { note in
                        NavigationLink(value: Route.spot(note.spotID)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(note.fromHandle) sent a pin")
                                    .font(Typeface.body(15, weight: .semibold))
                                Text(note.message)
                                    .font(Typeface.body(14))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Palette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var feed: some View {
        let following = Set(people.filter(\.isFollowing).map(\.handle))
        let recent = entries.filter { !$0.isMine && following.contains($0.authorHandle) }.prefix(6)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: "Their last light", title: "From the circle")
            if recent.isEmpty {
                QuietEmpty(
                    symbol: "person.2",
                    title: "A quiet circle",
                    detail: "Follow someone to see what they logged."
                )
            } else {
                ForEach(Array(recent), id: \.id) { entry in
                    NavigationLink(value: Route.entry(entry.id)) {
                        EntryCard(entry: entry, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FriendProfileView: View {
    let personID: UUID
    @Query private var people: [Person]
    @Query(sort: \SunsetEntry.capturedAt, order: .reverse) private var entries: [SunsetEntry]
    @Environment(\.modelContext) private var context
    @Environment(AppSession.self) private var session

    private var person: Person? { people.first { $0.id == personID } }

    var body: some View {
        Group {
            if let person {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            PersonMark(name: person.displayName, hue: person.avatarHue, size: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.displayName)
                                    .font(Typeface.display(30))
                                Text("@\(person.handle) · \(person.city)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(person.bio)
                            .font(Typeface.body(16))
                        EmberButton(
                            title: person.isFollowing ? "Following" : "Follow",
                            fill: !person.isFollowing
                        ) {
                            try? session.social.setFollowing(
                                personID: person.id,
                                isFollowing: !person.isFollowing,
                                context: context
                            )
                        }
                        SoftBanner(text: "Follow state lives in the mock social client — swap the client to go online.")
                        let theirs = entries.filter { $0.authorHandle == person.handle }
                        if theirs.isEmpty {
                            QuietEmpty(symbol: "sunset", title: "No evenings yet", detail: "When they log, their skies will land here.")
                        } else {
                            ForEach(theirs, id: \.id) { entry in
                                NavigationLink(value: Route.entry(entry.id)) {
                                    EntryCard(entry: entry, compact: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                QuietEmpty(symbol: "person", title: "Missing person", detail: "They are not in this mock circle.")
            }
        }
        .duskBackdrop()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedSpotsView: View {
    @Query(sort: \Spot.name) private var spots: [Spot]

    var body: some View {
        let saved = spots.filter(\.isSaved)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(eyebrow: "Bookmarks", title: "Saved spots")
                if saved.isEmpty {
                    QuietEmpty(
                        symbol: "bookmark",
                        title: "Nothing pinned",
                        detail: "Save a place from its page and it will wait here."
                    )
                } else {
                    ForEach(saved, id: \.id) { spot in
                        NavigationLink(value: Route.spot(spot.id)) {
                            HStack(spacing: 12) {
                                SkyPhoto(bundleName: spot.heroPhotoName, corner: 12)
                                    .frame(width: 72, height: 88)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(spot.name)
                                        .font(Typeface.display(20))
                                        .foregroundStyle(.primary)
                                    Text(spot.placeLine)
                                        .font(Typeface.caption(12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let avg = spot.averageOverall {
                                    Text(ScoreFormat.oneDecimal(avg))
                                        .font(Typeface.display(22))
                                        .foregroundStyle(Palette.ember)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .duskBackdrop()
        .navigationBarTitleDisplayMode(.inline)
    }
}
