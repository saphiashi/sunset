import SwiftUI

struct DuskCanvas: View {
    var body: some View {
        ZStack {
            Palette.canvas
            RadialGradient(
                colors: [Palette.gold.opacity(0.28), Color.clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [Palette.dusk.opacity(0.55), Color.clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 420
            )
            RadialGradient(
                colors: [Palette.rose.opacity(0.16), Color.clear],
                center: UnitPoint(x: 0.4, y: 0.15),
                startRadius: 0,
                endRadius: 220
            )
            LinearGradient(
                colors: [Color.black.opacity(0.18), Color.clear, Color.black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            GrainWash()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct GrainWash: View {
    var body: some View {
        Canvas { context, size in
            var rng = UInt64(2_654_435_761)
            for _ in 0..<520 {
                rng = rng &* 1_664_525 &+ 1_013_904_223
                let x = CGFloat(rng % 10_000) / 10_000 * size.width
                rng = rng &* 1_664_525 &+ 1_013_904_223
                let y = CGFloat(rng % 10_000) / 10_000 * size.height
                rng = rng &* 1_664_525 &+ 1_013_904_223
                let r: CGFloat = (rng % 3 == 0) ? 1.15 : 0.55
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.28)))
            }
        }
        .opacity(0.14)
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

struct GlowOrb: View {
    var color: Color = Palette.gold
    var size: CGFloat = 180

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.9), color.opacity(0.15), Color.clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 18)
            .allowsHitTesting(false)
    }
}

struct FeatherMask: View {
    var top: CGFloat = 0.16
    var bottom: CGFloat = 0.78

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: top),
                .init(color: .black, location: bottom),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Long ease-in/out so adjacent skies dissolve instead of meeting at a ledge.
struct WashMask: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.12), location: 0.06),
                .init(color: .black.opacity(0.40), location: 0.16),
                .init(color: .black.opacity(0.78), location: 0.30),
                .init(color: .black, location: 0.42),
                .init(color: .black, location: 0.54),
                .init(color: .black.opacity(0.72), location: 0.64),
                .init(color: .black.opacity(0.38), location: 0.76),
                .init(color: .black.opacity(0.12), location: 0.88),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct EdgeSoftMask: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.04),
                .init(color: .black, location: 0.96),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

