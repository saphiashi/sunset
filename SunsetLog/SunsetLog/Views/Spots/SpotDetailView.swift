import SwiftUI
import SwiftData
import MapKit

struct SpotDetailView: View {
    let spotID: UUID
    @Query private var spots: [Spot]
    @Query private var people: [Person]
    @Query private var notes: [SharedSpotNote]
    @Environment(\.modelContext) private var context
    @Environment(AppSession.self) private var session
    @State private var shareFriend: Person?
    @State private var shareMessage = "You should stand here once."
    @State private var didShare = false

    private var spot: Spot? { spots.first { $0.id == spotID } }

    var body: some View {
        Group {
            if let spot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero(spot)
                        header(spot)
                        scores(spot)
                        mapSnippet(spot)
                        actions(spot)
                        if didShare {
                            SoftBanner(text: "Sent through the mock circle. A real backend would notify them.")
                        }
                        incoming(spot)
                        recent(spot)
                    }
                    .padding(.bottom, 36)
                }
            } else {
                QuietEmpty(symbol: "mappin.slash", title: "Unknown place", detail: "This pin is no longer in the atlas.")
            }
        }
        .duskBackdrop()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareFriend) { person in
            shareSheet(person)
        }
    }

    private func hero(_ spot: Spot) -> some View {
        let photo = spot.entries.sorted { $0.overallScore > $1.overallScore }.first
        return ZStack(alignment: .bottomLeading) {
            SkyPhoto(
                bundleName: photo?.photoBundleName,
                fileName: photo?.photoFileName,
                corner: 0
            )
            .frame(height: 380)
            .overlay { SkyGradient.veil }
            VStack(alignment: .leading, spacing: 6) {
                Text(spot.name)
                    .font(Typeface.italic(36))
                    .foregroundStyle(.white)
                Text(spot.placeLine)
                    .font(Typeface.italic(14))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(22)
            .padding(.bottom, 8)
        }
    }

    private func header(_ spot: Spot) -> some View {
        Text(spot.blurb)
            .font(Typeface.italic(17))
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    private func scores(_ spot: Spot) -> some View {
        HStack {
            metric("Color", spot.averageColor)
            metric("Drama", spot.averageDrama)
            metric("Overall", spot.averageOverall)
        }
        .padding(.horizontal, 20)
    }

    private func metric(_ name: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name.uppercased())
                .font(Typeface.caption(10))
                .foregroundStyle(.secondary)
            Text(value.map(ScoreFormat.oneDecimal) ?? "—")
                .font(Typeface.display(26))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapSnippet(_ spot: Spot) -> some View {
        Map(initialPosition: .region(.init(center: spot.coordinate, span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04)))) {
            Marker(spot.name, coordinate: spot.coordinate)
                .tint(Palette.ember)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
        .allowsHitTesting(false)
    }

    private func actions(_ spot: Spot) -> some View {
        SpotActionBar(
            spot: spot,
            friends: people.filter { !$0.isMe },
            shareFriend: $shareFriend
        )
    }

    private func incoming(_ spot: Spot) -> some View {
        let mine = notes.filter { $0.spotID == spot.id }
        return Group {
            if !mine.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passed along")
                        .font(Typeface.display(22))
                    ForEach(mine, id: \.id) { note in
                        Text("\(note.fromHandle) → \(note.toHandle): \(note.message)")
                            .font(Typeface.body(14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func recent(_ spot: Spot) -> some View {
        let photos = spot.entries.sorted { $0.capturedAt > $1.capturedAt }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent skies")
                .font(Typeface.display(22))
            if photos.isEmpty {
                Text("No evenings logged here yet.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos, id: \.id) { entry in
                            SpotRecentThumb(entry: entry)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func shareSheet(_ person: Person) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Send \(spot?.name ?? "this pin") to \(person.displayName)")
                    .font(Typeface.display(24))
                TextField("A line to send with it", text: $shareMessage, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(12)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                EmberButton(title: "Send") {
                    if let spot {
                        try? session.social.shareSpot(
                            spotID: spot.id,
                            to: person.id,
                            message: shareMessage,
                            from: "you",
                            context: context
                        )
                        didShare = true
                    }
                    shareFriend = nil
                }
                Spacer()
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { shareFriend = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SpotActionBar: View {
    @Environment(\.modelContext) private var context
    let spot: Spot
    let friends: [Person]
    @Binding var shareFriend: Person?

    var body: some View {
        VStack(spacing: 10) {
            EmberButton(
                title: spot.isSaved ? "Saved to your atlas" : "Save this spot",
                systemImage: spot.isSaved ? "bookmark.fill" : "bookmark"
            ) {
                spot.isSaved.toggle()
                try? context.save()
            }
            ShareLink(
                item: DeepLink.spotURL(spot.id),
                subject: Text(spot.name),
                message: Text("A sunset place: \(spot.name). Open in Sunset Log.")
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share this pin")
                        .font(Typeface.body(16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.ember.opacity(0.45), lineWidth: 1)
                }
                .foregroundStyle(Palette.ember)
            }
            if !friends.isEmpty {
                Menu {
                    ForEach(friends, id: \.id) { person in
                        Button(person.displayName) {
                            shareFriend = person
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane")
                        Text("Send to someone in your circle")
                            .font(Typeface.body(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Palette.ember)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct SpotRecentThumb: View {
    let entry: SunsetEntry

    var body: some View {
        NavigationLink(value: Route.entry(entry.id)) {
            VStack(alignment: .leading, spacing: 6) {
                SkyPhoto(entry: entry, corner: 16)
                    .frame(width: 150, height: 190)
                Text(entry.authorName)
                    .font(Typeface.caption(12))
                Text(ScoreFormat.oneDecimal(entry.overallScore))
                    .font(Typeface.display(18))
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }
}
