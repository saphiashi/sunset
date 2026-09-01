import SwiftUI
import SwiftData
import MapKit

struct AtlasView: View {
    @Environment(AppSession.self) private var session
    @Query private var spots: [Spot]
    @State private var position: MapCameraPosition = .automatic
    @State private var onlyBest = true

    private var visible: [Spot] {
        spots.filter { spot in
            guard onlyBest else { return !spot.entries.isEmpty || spot.isSeed }
            return (spot.averageOverall ?? 0) >= 7.8 || spot.entries.contains(where: { $0.overallScore >= 8.0 })
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                ForEach(visible, id: \.id) { spot in
                    Annotation(spot.name, coordinate: spot.coordinate) {
                        SpotMapPin(spot: spot)
                    }
                }
                if let here = session.location.coordinate {
                    Annotation("You", coordinate: here) {
                        YouMapDot()
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 10) {
                Text("Evenings near you")
                    .font(Typeface.italic(28))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                    .padding(.horizontal, 4)
                if session.location.isDenied {
                    SoftBanner(text: "Location is off. The atlas is showing California seed spots.")
                } else if session.location.usesFallback {
                    SoftBanner(text: "Waiting on a fix. Pins are the seeded west coast for now.")
                }
                Toggle("Best only", isOn: $onlyBest)
                    .font(Typeface.caption(13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .frame(maxWidth: 160)
            }
            .padding(16)
        }
        .onAppear {
            recenter()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func recenter() {
        let coord = session.location.effectiveCoordinate
        position = .region(
            MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
            )
        )
    }
}

private struct SpotMapPin: View {
    let spot: Spot

    private var scoreLabel: String {
        ScoreFormat.oneDecimal(spot.averageOverall ?? spot.entries.map(\.overallScore).max() ?? 7.0)
    }

    var body: some View {
        NavigationLink(value: Route.spot(spot.id)) {
            VStack(spacing: 2) {
                Text(scoreLabel)
                    .font(Typeface.caption(11))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Palette.ember)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.ember)
                    .shadow(radius: 3)
            }
        }
    }
}

private struct YouMapDot: View {
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 12, height: 12)
            .overlay { Circle().stroke(.white, lineWidth: 2) }
    }
}
