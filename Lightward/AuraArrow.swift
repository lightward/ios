import SwiftUI

/// The Lightward arrow filled with a slowly shifting prismatic aura.
/// Uses MeshGradient for a rich, organic color field.
/// Animates on appearance, easing to a stop over ~2.5 seconds.
struct AuraArrow: View {
    var size: CGFloat = 80
    @State private var phase: Float = 0
    @State private var animating = false

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: meshPoints(at: phase),
            colors: meshColors(at: phase)
        )
        .mask {
            LightwardArrow()
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .onAppear {
            startAura()
        }
    }

    /// Start the aura animation, slowing to a stop over ~2.5 seconds.
    func startAura() {
        guard !animating else { return }
        animating = true

        Task { @MainActor in
            let start = Date()
            let duration: Double = 2.5

            while Date().timeIntervalSince(start) < duration {
                let elapsed = Date().timeIntervalSince(start)
                let progress = elapsed / duration
                let speed = Float(1.0 - (progress * progress))
                phase += 0.008 * speed
                try? await Task.sleep(for: .milliseconds(33))
            }
            animating = false
        }
    }

    /// Mesh points that drift slowly with the phase for organic movement.
    private func meshPoints(at phase: Float) -> [SIMD2<Float>] {
        let d: Float = 0.08 // drift amount
        let p = phase * .pi * 2
        return [
            [0, 0],
            [0.5 + sin(p * 1.1) * d, 0],
            [1, 0],
            [0, 0.5 + cos(p * 0.9) * d],
            [0.5 + sin(p * 0.7) * d, 0.5 + cos(p * 1.3) * d],
            [1, 0.5 + sin(p * 1.1) * d],
            [0, 1],
            [0.5 + cos(p * 0.8) * d, 1],
            [1, 1]
        ]
    }

    /// Prismatic colors that rotate through the aura palette.
    private func meshColors(at phase: Float) -> [Color] {
        let offsets: [Float] = [0, 0.12, 0.28, 0.4, 0.55, 0.7, 0.2, 0.48, 0.85]
        return offsets.map { offset in
            auraColor(at: Double((phase + offset).truncatingRemainder(dividingBy: 1.0)))
        }
    }

    private func auraColor(at t: Double) -> Color {
        let p = t < 0 ? t + 1 : t

        switch p {
        case 0..<0.2:
            return interpolate(.auraAmber, .auraRose, t: p / 0.2)
        case 0.2..<0.4:
            return interpolate(.auraRose, .auraViolet, t: (p - 0.2) / 0.2)
        case 0.4..<0.6:
            return interpolate(.auraViolet, .auraCyan, t: (p - 0.4) / 0.2)
        case 0.6..<0.8:
            return interpolate(.auraCyan, .auraGreen, t: (p - 0.6) / 0.2)
        default:
            return interpolate(.auraGreen, .auraAmber, t: (p - 0.8) / 0.2)
        }
    }

    private func interpolate(_ a: Color, _ b: Color, t: Double) -> Color {
        let t = max(0, min(1, t))
        let ac = a.rgbComponents
        let bc = b.rgbComponents
        return Color(
            red: ac.r + (bc.r - ac.r) * t,
            green: ac.g + (bc.g - ac.g) * t,
            blue: ac.b + (bc.b - ac.b) * t
        )
    }
}

// MARK: - Aura palette

extension Color {
    static let auraAmber = Color(red: 0.95, green: 0.75, blue: 0.2)
    static let auraRose = Color(red: 0.9, green: 0.35, blue: 0.45)
    static let auraViolet = Color(red: 0.55, green: 0.3, blue: 0.7)
    static let auraCyan = Color(red: 0.1, green: 0.8, blue: 0.85)
    static let auraGreen = Color(red: 0.3, green: 0.75, blue: 0.45)

    var rgbComponents: (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: nil)
        return (Double(r), Double(g), Double(b))
    }
}
