import SwiftUI

enum Typeface {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
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
}
