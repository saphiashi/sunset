import SwiftUI

enum VeilStyle {
    case page
    case compact

    var height: CGFloat {
        switch self {
        case .page: return 700
        case .compact: return 390
        }
    }

    /// Negative VStack spacing. Keep ~57% overlap so taller veils still dissolve,
    /// while the unique visible band grows with height.
    var overlap: CGFloat {
        switch self {
        case .page: return -400
        case .compact: return -220
        }
    }
}

struct JournalVeil: View {
    let entry: SunsetEntry
    var style: VeilStyle = .page

    var body: some View {
        ZStack(alignment: .center) {
            wash
            VeilCaption(entry: entry, compact: style == .compact)
                .padding(.horizontal, 24)
                .padding(.bottom, style == .page ? 8 : 4)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: style.height)
        .compositingGroup()
        .mask { WashMask() }
    }

    private var wash: some View {
        ZStack {
            SkyPhoto(entry: entry, corner: 0)
                .blur(radius: 52)
                .scaleEffect(1.2)
                .opacity(0.38)
            SkyPhoto(entry: entry, corner: 0)
                .opacity(0.94)
            captionScrim
        }
        .allowsHitTesting(false)
    }

    private var captionScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.08), location: 0.32),
                .init(color: .black.opacity(0.38), location: 0.48),
                .init(color: .black.opacity(0.22), location: 0.62),
                .init(color: .clear, location: 0.82)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

struct JournalRibbon: View {
    let entries: [SunsetEntry]
    var style: VeilStyle = .page

    var body: some View {
        VStack(spacing: style.overlap) {
            ForEach(entries, id: \.id) { entry in
                NavigationLink(value: Route.entry(entry.id)) {
                    JournalVeil(entry: entry, style: style)
                }
                .buttonStyle(VeilPressStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.horizontal)
        .ignoresSafeArea(edges: .horizontal)
        .padding(.top, style == .page ? 4 : 0)
        .padding(.bottom, 48)
    }
}

struct VeilCaption: View {
    let entry: SunsetEntry
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            Text(entry.spot?.name ?? "An unmarked sky")
                .font(Typeface.display(compact ? 26 : 34))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 2)
            Text(meta)
                .font(Typeface.italic(14))
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            if !compact, !entry.note.isEmpty {
                Text(entry.note)
                    .font(Typeface.italic(16))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            }
            VeilScores(color: entry.colorScore, drama: entry.dramaScore, overall: entry.overallScore)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meta: String {
        let day = entry.capturedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        if entry.isMine { return day }
        return "\(entry.authorName)  ·  \(day)"
    }
}

struct VeilScores: View {
    let color: Double
    let drama: Double
    let overall: Double

    var body: some View {
        HStack(spacing: 14) {
            scoreChip("Color", color)
            scoreChip("Drama", drama)
            scoreChip("Overall", overall)
        }
    }

    private func scoreChip(_ name: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name.uppercased())
                .font(Typeface.caption(9))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.7))
            Text(ScoreFormat.oneDecimal(value))
                .font(Typeface.display(18))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.45), radius: 8, y: 1)
    }
}

struct VeilPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct EntryCard: View {
    let entry: SunsetEntry
    var compact: Bool

    var body: some View {
        JournalVeil(entry: entry, style: compact ? .compact : .page)
    }
}
