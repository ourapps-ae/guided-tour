import Foundation

// The placement maths of the animated background: glyphs drifting toward the viewer, and specks.
// Matches web/background.ts glyphFrame and speckFrame.
struct GlyphParticle {
    let x: Double, y: Double, period: Double, phase: Double, spin: Double, sway: Double, glyphIndex: Int

    init(x: Double, y: Double, period: Double, phase: Double, spin: Double, sway: Double, glyphIndex: Int) {
        self.x = x; self.y = y; self.period = period; self.phase = phase; self.spin = spin; self.sway = sway; self.glyphIndex = glyphIndex
    }

    init(seed: Int, glyphCount: Int = 4) {
        var s = UInt64(seed &* 7919 &+ 13)
        func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 11) / Double(1 << 53)
        }
        x = next() * 1.6 - 0.8
        y = next() * 1.4 - 0.7
        period = 14 + next() * 12
        phase = next()
        spin = (next() - 0.5) * 30
        sway = next() * 2 * .pi
        glyphIndex = min(glyphCount - 1, Int(next() * Double(glyphCount)))
    }
}

struct Speck {
    let x: Double, phase: Double, period: Double, size: Double, wobble: Double

    init(x: Double, phase: Double, period: Double, size: Double, wobble: Double) {
        self.x = x; self.phase = phase; self.period = period; self.size = size; self.wobble = wobble
    }

    init(seed: Int) {
        var s = UInt64(seed &* 31 &+ 7)
        func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 11) / Double(1 << 53)
        }
        x = next()
        phase = next()
        period = 18 + next() * 20
        size = 1.5 + next() * 2.5
        wobble = next() * 2 * .pi
    }
}

struct GlyphFrame {
    let x: Double, y: Double, size: Double, alpha: Double, rotationDegrees: Double
}

struct SpeckFrame {
    let x: Double, y: Double, radius: Double, alpha: Double
}

enum BackgroundMath {
    static let particles = (0..<14).map { GlyphParticle(seed: $0) }
    static let specks = (0..<120).map { Speck(seed: $0) }

    static func flicker(_ style: ThemeBackgroundStyle, _ t: Double) -> Double {
        style.glowFromTop ? 0.75 + 0.1 * sin(t * 0.7) : 0.6 + 0.2 * sin(t * 1.3) * sin(t * 0.7)
    }

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }

    // `t` is already multiplied by the style's speed. nil when off screen or too faint.
    static func glyphFrame(_ p: GlyphParticle, style: ThemeBackgroundStyle, t: Double, light: Double, width: Double, height: Double) -> GlyphFrame? {
        let z = 1 - (t / p.period + p.phase).truncatingRemainder(dividingBy: 1)
        let depth = 0.08 + z * 0.92
        let scale = 0.1 / depth
        let x = width * (0.5 + p.x / depth * 0.5 + 0.02 * sin(t * 0.6 + p.sway))
        let y = height * (0.5 + p.y / depth * 0.5 + 0.015 * sin(t * 0.8 + p.sway * 2))
        let size = width * scale
        if x < -size || x > width + size || y < -size || y > height + size { return nil }
        let alpha = style.suitAlpha * clamp01((1 - z) * 4) * clamp01(z * 5) * (0.6 + 0.4 * min(light, 1.2)) * (1 - depth * 0.5)
        if alpha <= 0.01 { return nil }
        return GlyphFrame(x: x, y: y, size: size, alpha: alpha, rotationDegrees: p.spin * (1 - z))
    }

    static func speckFrame(_ sp: Speck, style: ThemeBackgroundStyle, t: Double, width: Double, height: Double) -> SpeckFrame {
        let f = (t / sp.period + sp.phase).truncatingRemainder(dividingBy: 1)
        let y = style.speckUp ? 1 - f : f
        let x = sp.x + 0.02 * sin(t * 0.5 + sp.wobble)
        let a = (0.25 + 0.2 * sin(t * 1.3 + sp.wobble)) * clamp01(1 - abs(y - 0.5) * 1.2)
        return SpeckFrame(x: x * width, y: y * height, radius: sp.size, alpha: a)
    }
}
