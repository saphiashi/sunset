import SwiftUI
import SwiftData

struct ExpandedPhoto: Identifiable, Equatable {
    let id: UUID
}

struct JournalLightbox: View {
    let entryID: UUID
    var onOpenDetails: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [SunsetEntry]
    @State private var drag: CGFloat = 0

    private var entry: SunsetEntry? {
        entries.first { $0.id == entryID }
    }

    var body: some View {
        ZStack {
            Palette.night.ignoresSafeArea()
            if let entry {
                photoStack(entry)
            } else {
                QuietEmpty(symbol: "photo", title: "This evening left", detail: "The photograph is no longer in the journal.")
            }
        }
        .offset(y: drag)
        .gesture(dismissDrag)
        .accessibilityAddTraits(.isModal)
    }

    private func photoStack(_ entry: SunsetEntry) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                SkyPhoto(entry: entry, corner: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LinearGradient(
                    colors: [.black.opacity(0.35), .clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                closeButton
                VeilCaption(entry: entry, compact: true)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 12) {
                EmberButton(title: "Open this evening", systemImage: "book.closed") {
                    onOpenDetails()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.night)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(.ultraThinMaterial.opacity(0.45), in: Circle())
        }
        .accessibilityLabel("Close")
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                drag = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 220 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        drag = 0
                    }
                }
            }
    }
}
