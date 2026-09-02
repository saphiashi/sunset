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
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            DuskCanvas()
                .opacity(0.55)
                .allowsHitTesting(false)
            if let entry {
                photoStack(entry)
            } else {
                QuietEmpty(symbol: "photo", title: "This evening left", detail: "The photograph is no longer in the journal.")
            }
        }
        .ignoresSafeArea()
        .offset(y: drag)
        .gesture(dismissDrag)
        .accessibilityAddTraits(.isModal)
    }

    private func photoStack(_ entry: SunsetEntry) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            SkyPhoto(entry: entry, corner: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 10) {
                VeilCaption(entry: entry, compact: false)
                EmberButton(title: "Open this evening", systemImage: "book.closed") {
                    onOpenDetails()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
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
