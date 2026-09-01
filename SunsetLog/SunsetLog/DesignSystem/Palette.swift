import SwiftUI
import UIKit

enum Palette {
    static let ember = Color(red: 0.93, green: 0.48, blue: 0.28)
    static let gold = Color(red: 0.96, green: 0.78, blue: 0.48)
    static let rose = Color(red: 0.90, green: 0.52, blue: 0.58)
    static let dusk = Color(red: 0.22, green: 0.14, blue: 0.32)
    static let ink = Color(red: 0.10, green: 0.07, blue: 0.10)
    static let paper = Color(red: 0.93, green: 0.84, blue: 0.76)
    static let mist = Color(red: 0.72, green: 0.62, blue: 0.58)
    static let storm = Color(red: 0.36, green: 0.30, blue: 0.46)
    static let night = Color(red: 0.07, green: 0.05, blue: 0.10)
    static let bloom = Color(red: 1.0, green: 0.62, blue: 0.38)

    static let canvas = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.06, green: 0.05, blue: 0.09, alpha: 1)
        }
        return UIColor(red: 0.90, green: 0.78, blue: 0.70, alpha: 1)
    })

    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.16, green: 0.12, blue: 0.18, alpha: 0.72)
        }
        return UIColor(red: 1.0, green: 0.94, blue: 0.88, alpha: 0.55)
    })

    static let hairline = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(white: 1, alpha: 0.12)
        }
        return UIColor(red: 0.42, green: 0.22, blue: 0.18, alpha: 0.16)
    })

    static let colorTrack = [Color(red: 0.45, green: 0.22, blue: 0.55), rose, gold, ember]
    static let dramaTrack = [dusk, storm, ember, Color(red: 0.55, green: 0.12, blue: 0.16)]
    static let overallTrack = [mist, gold, ember]
}

enum SkyGradient {
    static let dusk = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.10, blue: 0.22),
            Color(red: 0.46, green: 0.18, blue: 0.28),
            Color(red: 0.86, green: 0.46, blue: 0.26)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let veil = LinearGradient(
        colors: [
            Color.black.opacity(0.05),
            Color.black.opacity(0.15),
            Color.black.opacity(0.62)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum Typeface {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func italic(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

struct ScreenPadding: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, 20)
    }
}

extension View {
    func screenPadding() -> some View {
        modifier(ScreenPadding())
    }

    func duskBackdrop() -> some View {
        background { DuskCanvas() }
    }
}
