import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct LogSunsetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSession.self) private var session
    @Query(sort: \Spot.name) private var spots: [Spot]

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedAt = Date()
    @State private var note = ""
    @State private var color = 7.4
    @State private var drama = 6.8
    @State private var overall = 7.6
    @State private var selectedSpot: Spot?
    @State private var draftSpotName = ""
    @State private var error: String?
    @State private var useCurrentLocation = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    photoBlock
                    timeBlock
                    spotBlock
                    ScoreRail(title: "Color", whisper: "Wash · glow · fire", value: $color, colors: Palette.colorTrack)
                    ScoreRail(title: "Drama", whisper: "Calm · weather · tempest", value: $drama, colors: Palette.dramaTrack)
                    ScoreRail(title: "Overall", whisper: "Would you walk back for it?", value: $overall, colors: Palette.overallTrack)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A short note")
                            .font(Typeface.body(15, weight: .semibold))
                        TextField("What did the sky do?", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(Palette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if let error {
                        Text(error)
                            .font(Typeface.caption(13))
                            .foregroundStyle(.red)
                    }
                    EmberButton(title: "Keep this evening", systemImage: "checkmark") {
                        save()
                    }
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Log a sunset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if selectedSpot == nil {
                    selectedSpot = nearestSpot()
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $image)
                    .ignoresSafeArea()
            }
        }
    }

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image {
                SkyPhoto(image: image, corner: 22)
                    .frame(height: 280)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SkyGradient.dusk)
                    VStack(spacing: 8) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 28, weight: .light))
                        Text("The photograph")
                            .font(Typeface.display(22))
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 220)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    labelChip("Library", "photo")
                }
                .onChange(of: pickerItem) { _, item in
                    Task { await loadPicker(item) }
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: { labelChip("Camera", "camera") }
                }
            }
        }
    }

    private func labelChip(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(Typeface.body(14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.card)
            .clipShape(Capsule())
    }

    private var timeBlock: some View {
        DatePicker("When the light went", selection: $capturedAt)
            .font(Typeface.body(15, weight: .semibold))
            .padding(14)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var spotBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where you stood")
                .font(Typeface.body(15, weight: .semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(spots, id: \.id) { spot in
                        LogSpotChip(
                            title: spot.name,
                            isOn: selectedSpot?.id == spot.id
                        ) {
                            selectedSpot = spot
                            draftSpotName = ""
                        }
                    }
                }
            }
            TextField("Or name a new spot", text: $draftSpotName)
                .padding(14)
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onChange(of: draftSpotName) { _, text in
                    if !text.isEmpty { selectedSpot = nil }
                }
            Toggle("Drop a pin at my current location", isOn: $useCurrentLocation)
                .font(Typeface.body(14))
        }
    }

    private func loadPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            image = ui
        }
    }

    private func nearestSpot() -> Spot? {
        let here = session.location.effectiveCoordinate
        return spots.min {
            hypot($0.latitude - here.latitude, $0.longitude - here.longitude)
            < hypot($1.latitude - here.latitude, $1.longitude - here.longitude)
        }
    }

    private func save() {
        error = nil
        let file = image.flatMap { ImageStore.save($0) }
        if image != nil && file == nil {
            error = "The photograph could not be kept on disk."
            return
        }

        let entry = SunsetEntry(
            capturedAt: capturedAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            colorScore: color,
            dramaScore: drama,
            overallScore: overall,
            photoFileName: file,
            authorHandle: "you",
            authorName: "You",
            isMine: true
        )

        if let selectedSpot {
            entry.spot = selectedSpot
        } else {
            let name = draftSpotName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                let coord = useCurrentLocation ? session.location.effectiveCoordinate : LocationService.fallback
                let spot = Spot(
                    name: name,
                    locality: session.location.locality ?? LocationService.fallbackLocality,
                    region: "",
                    blurb: "A place you named.",
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
                context.insert(spot)
                entry.spot = spot
            }
        }

        context.insert(entry)
        do {
            try context.save()
            dismiss()
        } catch {
            self.error = "Could not save this evening."
        }
    }
}

private struct LogSpotChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.caption(13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? Palette.ember : Palette.card)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
