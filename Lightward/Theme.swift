import SwiftUI

extension Color {
    /// #1a1a1a — the dark ground
    static let background = Color(red: 0.1, green: 0.1, blue: 0.1)

    /// #e8e4df — warm off-white text
    static let warmText = Color(red: 0.91, green: 0.894, blue: 0.875)

    /// #c4a882 — warm gold accent
    static let warmAccent = Color(red: 0.769, green: 0.659, blue: 0.51)
}

extension ShapeStyle where Self == Color {
    static var warmText: Color { .warmText }
    static var warmAccent: Color { .warmAccent }
    static var background: Color { .background }
}
