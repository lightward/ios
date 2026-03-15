import SwiftUI

/// The Lightward arrow, pointing up.
/// Based on Lightward_VectorWordmark-03.svg, rotated from right-pointing to up-pointing.
struct LightwardArrow: Shape {
    func path(in rect: CGRect) -> Path {
        // Original SVG path is right-pointing in a 1080x1080 viewBox.
        // We rotate 90° counter-clockwise to point up.
        let scale = min(rect.width, rect.height) / 1080

        var path = Path()

        // Rotated coordinates: (x, y) → (y, 1080-x)
        // Original key points of the arrow, rotated to point up:
        path.move(to: CGPoint(x: 515.19 * scale, y: (1080 - 651.37) * scale))
        path.addLine(to: CGPoint(x: 403.27 * scale, y: (1080 - 538.9) * scale))
        path.addLine(to: CGPoint(x: (403.27 + 34.18) * scale, y: (1080 - 538.9 - 33.63) * scale))

        // Simpler approach: use the SVG path with a rotation transform
        return Path { p in
            // Original arrow path (right-pointing)
            p.move(to: CGPoint(x: 651.37, y: 515.19))
            p.addLine(to: CGPoint(x: 538.9, y: 403.27))
            p.addLine(to: CGPoint(x: 572.53, y: 369.09))
            p.addLine(to: CGPoint(x: 744, y: 539.45))
            p.addLine(to: CGPoint(x: 572.53, y: 710.91))
            p.addLine(to: CGPoint(x: 538.9, y: 676.73))
            p.addLine(to: CGPoint(x: 650.81, y: 564.81))
            p.addLine(to: CGPoint(x: 336, y: 564.81))
            p.addLine(to: CGPoint(x: 336, y: 515.19))
            p.closeSubpath()
        }
        .applying(
            CGAffineTransform(translationX: -540, y: -540)
                .concatenating(CGAffineTransform(rotationAngle: -.pi / 2))
                .concatenating(CGAffineTransform(translationX: 540, y: 540))
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        )
    }
}

/// Convenience view for the arrow at a specific size.
struct LightwardArrowView: View {
    var size: CGFloat = 20
    var color: Color = .warmAccent

    var body: some View {
        LightwardArrow()
            .fill(color)
            .frame(width: size, height: size)
    }
}
