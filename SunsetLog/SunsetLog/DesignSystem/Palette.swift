import SwiftUI
import UIKit

enum Palette {
    static let ember = Color(red: 0.88, green: 0.42, blue: 0.24)
    static let gold = Color(red: 0.91, green: 0.72, blue: 0.42)
    static let rose = Color(red: 0.86, green: 0.48, blue: 0.52)
    static let dusk = Color(red: 0.24, green: 0.16, blue: 0.32)
    static let ink = Color(red: 0.10, green: 0.07, blue: 0.07)
    static let paper = Color(red: 0.97, green: 0.93, blue: 0.89)
    static let mist = Color(red: 0.62, green: 0.54, blue: 0.50)
    static let storm = Color(red: 0.36, green: 0.30, blue: 0.46)

    static let canvas = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.08, green: 0.06, blue: 0.07, alpha: 1)
        }
        return UIColor(red: 0.97, green: 0.93, blue: 0.89, alpha: 1)
    })

    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.14, green: 0.11, blue: 0.12, alpha: 1)
        }
        return UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1)
    })

    static let hairline = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(white: 1, alpha: 0.10)
        }
        return UIColor(red: 0.42, green: 0.28, blue: 0.20, alpha: 0.12)
    })

    static let colorTrack = [Color(red: 0.45, green: 0.22, blue: 0.55), rose, gold, ember]
    static let dramaTrack = [dusk, storm, ember, Color(red: 0.55, green: 0.12, blue: 0.16)]
    static let overallTrack = [mist, gold, ember]
}

enum SkyGradient {
    static let dusk = LinearGradient(
        colors: [
            Color(red: 0.16, green: 0.12, blue: 0.22),
            Color(red: 0.42, green: 0.18, blue: 0.22),
            Color(red: 0.72, green: 0.38, blue: 0.24)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
