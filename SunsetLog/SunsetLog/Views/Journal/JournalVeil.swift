import SwiftUI

enum VeilStyle {
    case page
    case compact
}

struct JournalVeil: View {
    let entry: SunsetEntry
    var style: VeilStyle = .page
    var staggered: Bool = false

    private var height: CGFloat {
        switch style {
        case .page: return staggered ? 400 : 460
        case .compact: return 250
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            bloom
            photograph
            SkyGradient.veil
            VeilCaption(entry: entry, compact: style == .compact)
                .padding(.horizontal, 22)
                .padding(.bottom, style == .page ? 36 : 22)
        }
        .frame(height: height)
        .padding(.horizontal, staggered ? 22 : 0)
    }

    private var bloom: some View {
        SkyPhoto(entry: entry, corner: 0)
            .blur(radius: 28)
            .scaleEffect(1.12)
            .opacity(0.55)
            .allowsHitTesting(false)
    }

    private var photograph: some View {
        SkyPhoto(entry: entry, corner: 0)
            .mask(FeatherMask(top: style == .compact ? 0.06 : 0.12, bottom: 0.84))
    }
}

struct JournalRibbon: View {
    let entries: [SunsetEntry]

    var body: some View {
        VStack(spacing: -118) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                NavigationLink(value: Route.entry(entry.id)) {
                    JournalVeil(entry: entry, style: .page, staggered: index.isMultiple(of: 2) == false)
                }
                .buttonStyle(VeilPressStyle())
                .zIndex(Double(entries.count - index))
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 72)
    }
}

struct VeilCaption: View {
    let entry: SunsetEntry
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text(entry.spot?.name ?? "An unmarked sky")
                .font(Typeface.display(compact ? 26 : 34))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            Text(meta)
                .font(Typeface.italic(14))
                .foregroundStyle(.white.opacity(0.84))
            if !compact, !entry.note.isEmpty {
                Text(entry.note)
                    .font(Typeface.italic(16))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
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
        HStack(spacing: 8) {
            scoreChip("Color", color)
            scoreChip("Drama", drama)
            scoreChip("Overall", overall)
        }
    }

    private func scoreChip(_ name: String, _ value: Double) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(Typeface.caption(9))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.7))
            Text(ScoreFormat.oneDecimal(value))
                .font(Typeface.display(16))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.55), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        }
    }
}

struct VeilPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.22), value: configuration.isPressed)
    }
}

/// Shared compact overlay used on Tonight, Circle, and the day calendar.
struct EntryCard: View {
    let entry: SunsetEntry
    var compact: Bool

    var body: some View {
        JournalVeil(entry: entry, style: compact ? .compact : .page)
    }
}
