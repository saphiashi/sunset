import SwiftUI
import UIKit

struct EmberButton: View {
    let title: String
    var systemImage: String? = nil
    var fill: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(Typeface.body(16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(fill ? Palette.ember : Color.clear)
            .foregroundStyle(fill ? Color.white : Palette.ember)
            .overlay {
                if !fill {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.ember.opacity(0.45), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    var accessory: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(Typeface.caption(11))
                .tracking(1.4)
                .foregroundStyle(Palette.ember)
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Typeface.display(28))
                Spacer()
                if let accessory {
                    Text(accessory)
                        .font(Typeface.caption(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ScoreRail: View {
    let title: String
    let whisper: String
    @Binding var value: Double
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typeface.body(15, weight: .semibold))
                    Text(whisper)
                        .font(Typeface.caption(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(ScoreFormat.oneDecimal(value))
                    .font(Typeface.display(32))
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                let width = geo.size.width
                let t = CGFloat((value - 1) / 9)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .opacity(0.28)
                    Capsule()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(28, width * t))
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                        .frame(width: 26, height: 26)
                        .offset(x: max(0, min(width - 26, width * t - 13)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let raw = drag.location.x / max(width, 1)
                            let next = 1 + Double(raw) * 9
                            value = (min(10, max(1, next)) * 10).rounded() / 10
                        }
                )
            }
            .frame(height: 28)
        }
        .padding(16)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.hairline, lineWidth: 1)
        }
        .animation(.snappy(duration: 0.18), value: value)
    }
}

struct ScorePills: View {
    let color: Double
    let drama: Double
    let overall: Double

    var body: some View {
        HStack(spacing: 8) {
            pill("Color", color)
            pill("Drama", drama)
            pill("Overall", overall)
        }
    }

    private func pill(_ name: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name.uppercased())
                .font(Typeface.caption(9))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(ScoreFormat.oneDecimal(value))
                .font(Typeface.display(18))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Palette.card.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct QuietEmpty: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.ember)
            Text(title)
                .font(Typeface.display(24))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(Typeface.body(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                EmberButton(title: actionTitle, action: action)
                    .frame(maxWidth: 260)
                    .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct PermissionCard: View {
    let title: String
    let detail: String
    let button: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Typeface.display(22))
            Text(detail)
                .font(Typeface.body(15))
                .foregroundStyle(.secondary)
            EmberButton(title: button, systemImage: "gear", action: action)
        }
        .padding(20)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.hairline, lineWidth: 1)
        }
    }
}

struct PersonMark: View {
    let name: String
    let hue: Double
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.45, brightness: 0.85),
                            Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.55),
                            Color(hue: hue, saturation: 0.45, brightness: 0.85)
                        ],
                        center: .center
                    )
                )
            Text(initials)
                .font(Typeface.body(size * 0.34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

struct SkyPhoto: View {
    var bundleName: String? = nil
    var fileName: String? = nil
    var image: UIImage? = nil
    var corner: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            resolved
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(SkyGradient.dusk)
        }
    }

    private var resolved: Image {
        if let image {
            return Image(uiImage: image)
        }
        if let fileName, let stored = ImageStore.load(fileName) {
            return Image(uiImage: stored)
        }
        if let bundleName, let bundled = ImageStore.bundleImage(named: bundleName) {
            return Image(uiImage: bundled)
        }
        return Image(systemName: "sun.horizon.fill")
    }
}

extension SkyPhoto {
    init(entry: SunsetEntry, corner: CGFloat = 22) {
        self.init(
            bundleName: entry.photoBundleName,
            fileName: entry.photoFileName,
            image: nil,
            corner: corner
        )
    }
}

struct SoftBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typeface.caption(12))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.gold.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

enum SettingsDeeplink {
    static func open() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
