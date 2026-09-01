import SwiftUI
import SwiftData

struct LibraryScanView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var spots: [Spot]
    @State private var selected: ScanCandidate?
    @State private var importedCount = 0

    var body: some View {
        @Bindable var scanner = session.scanner
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(eyebrow: "Camera roll", title: "Evenings you already had")
                Text("We look for photographs taken near local sunset, with a warm sky. You rate them before they enter the journal.")
                    .font(Typeface.body(15))
                    .foregroundStyle(.secondary)

                switch scanner.access {
                case .denied:
                    PermissionCard(
                        title: "Photos are closed",
                        detail: "Sunset Log only reads the library to find old skies. Nothing is uploaded.",
                        button: "Open Settings"
                    ) {
                        SettingsDeeplink.open()
                    }
                case .notDetermined, .unknown:
                    EmberButton(title: "Allow photo access", systemImage: "photo") {
                        Task {
                            await scanner.requestAccess()
                            await runScan()
                        }
                    }
                case .unavailable:
                    QuietEmpty(symbol: "photo.badge.exclamationmark", title: "Photos unavailable", detail: "This device cannot open the library.")
                case .limited, .authorized:
                    if scanner.access == .limited {
                        SoftBanner(text: "Limited access. You can add more photographs from Settings.")
                    }
                    if scanner.isScanning {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Reading the roll…")
                                .font(Typeface.body(15))
                        }
                        .padding(.vertical, 20)
                    } else if scanner.candidates.isEmpty {
                        QuietEmpty(
                            symbol: "moon.haze",
                            title: "No likely sunsets",
                            detail: "Nothing in the recent roll looked like last light. Try after a walk, or log tonight by hand.",
                            actionTitle: "Scan again"
                        ) {
                            Task { await runScan() }
                        }
                    } else {
                        if scanner.candidates.contains(where: \.isSimulatorDemo) {
                            SoftBanner(text: "Simulator demo finds — the real device uses PhotoKit on your roll.")
                        }
                        ForEach(scanner.candidates) { candidate in
                            Button {
                                selected = candidate
                            } label: {
                                candidateRow(candidate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if importedCount > 0 {
                    SoftBanner(text: "Imported \(importedCount) evening\(importedCount == 1 ? "" : "s") into the journal.")
                }
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            scanner.refreshAccess()
            if scanner.access == .authorized || scanner.access == .limited {
                await runScan()
            }
        }
        .sheet(item: $selected) { candidate in
            ScanReviewView(candidate: candidate) { imported in
                if imported { importedCount += 1 }
                scanner.candidates.removeAll { $0.id == candidate.id }
                selected = nil
            }
        }
    }

    private func candidateRow(_ candidate: ScanCandidate) -> some View {
        HStack(spacing: 12) {
            SkyPhoto(image: candidate.preview, corner: 12)
                .frame(width: 84, height: 104)
            VStack(alignment: .leading, spacing: 6) {
                Text(candidate.createdAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(Typeface.body(15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(candidate.reason)
                    .font(Typeface.caption(12))
                    .foregroundStyle(.secondary)
                Text("Review & rate")
                    .font(Typeface.caption(12))
                    .foregroundStyle(Palette.ember)
            }
            Spacer()
        }
    }

    private func runScan() async {
        await session.scanner.scan(
            near: session.location.effectiveCoordinate.latitude,
            longitude: session.location.effectiveCoordinate.longitude
        )
    }
}

struct ScanReviewView: View {
    let candidate: ScanCandidate
    var onFinish: (Bool) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Spot.name) private var spots: [Spot]
    @State private var color = 7.5
    @State private var drama = 6.5
    @State private var overall = 7.5
    @State private var note = ""
    @State private var selectedSpotID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SkyPhoto(image: candidate.preview, corner: 20)
                        .frame(height: 320)
                    Text(candidate.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                        .font(Typeface.display(24))
                    Text(candidate.reason)
                        .foregroundStyle(.secondary)
                    Picker("Spot", selection: $selectedSpotID) {
                        Text("No spot").tag(Optional<UUID>.none)
                        ForEach(spots, id: \.id) { spot in
                            Text(spot.name).tag(Optional(spot.id))
                        }
                    }
                    ScoreRail(title: "Color", whisper: "How warm was it?", value: $color, colors: Palette.colorTrack)
                    ScoreRail(title: "Drama", whisper: "Did the weather speak?", value: $drama, colors: Palette.dramaTrack)
                    ScoreRail(title: "Overall", whisper: "Keep it?", value: $overall, colors: Palette.overallTrack)
                    TextField("A note, if you remember", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    EmberButton(title: "Import this evening") {
                        importIt()
                    }
                    Button("Skip") { onFinish(false) }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            selectedSpotID = spots.first?.id
        }
    }

    private func importIt() {
        var file: String?
        if let preview = candidate.preview {
            file = ImageStore.save(preview)
        }
        let entry = SunsetEntry(
            capturedAt: candidate.createdAt,
            note: note,
            colorScore: color,
            dramaScore: drama,
            overallScore: overall,
            photoBundleName: candidate.isSimulatorDemo ? String(candidate.assetID.dropFirst(5)) : nil,
            photoFileName: file,
            photoAssetId: candidate.isSimulatorDemo ? nil : candidate.assetID,
            authorHandle: "you",
            authorName: "You",
            isMine: true,
            importedFromLibrary: true
        )
        entry.spot = spots.first { $0.id == selectedSpotID }
        context.insert(entry)
        try? context.save()
        onFinish(true)
    }
}
