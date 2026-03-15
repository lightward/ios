import SwiftUI

extension Color {
    /// Charcoal #121010 — the brand's dark ground
    static let background = Color(red: 0.071, green: 0.063, blue: 0.063)

    /// Linen #FFF6E7 — warm cream text on dark
    static let warmText = Color(red: 1.0, green: 0.965, blue: 0.906)

    /// Golden #F9C950 — brand accent
    static let warmAccent = Color(red: 0.976, green: 0.788, blue: 0.314)

    /// Faint — linen at low opacity for secondary elements
    static let faint = Color(red: 1.0, green: 0.965, blue: 0.906).opacity(0.3)
}

/// Layout constants shared across phoropter and chat views.
enum Layout {
    /// Width of the left gutter column (icons, manicules, message markers).
    static let gutterWidth: CGFloat = 24
    /// Horizontal padding from screen edge.
    static let horizontalPadding: CGFloat = 28
    /// Gap between gutter and content.
    static let gutterGap: CGFloat = 10
}

extension ShapeStyle where Self == Color {
    static var warmText: Color { .warmText }
    static var warmAccent: Color { .warmAccent }
    static var background: Color { .background }
    static var faint: Color { Color.faint }
}
