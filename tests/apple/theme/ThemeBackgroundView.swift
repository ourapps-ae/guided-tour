#if canImport(UIKit)
import SwiftUI
import UIKit

extension Color {
    init(_ c: ThemeColour) { self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha) }
}

extension ThemeColour {
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
}

// A figure in front of the animation, in a corner of the screen.
struct SceneFront {
    enum Corner { case topLeft, bottomLeft, bottomRight }
    let at: Corner
    let h: CGFloat
    let maxW: CGFloat
    var flipX = false
    var flipY = false
}

// Pictures behind and in front of the animation. The application loads the images (from its own
// bundle) and names the scene so the scaled picture can be cached. anchor 0 shows the top of a
// picture taller than the screen, 1 the bottom.
struct BackgroundScene {
    var id = "default"
    var back: UIImage? = nil
    var front: UIImage? = nil
    var anchor: CGFloat = 0.5
    var fronts: [SceneFront] = []
}

// The scene picture scaled to the screen once and the glyphs drawn once per theme, so a frame is a
// few image blits rather than a decode and a text layout.
private enum Prerendered {
    static var backs: [String: UIImage] = [:]
    static var glyphs: [String: [UIImage]] = [:]

    static func back(_ scene: BackgroundScene, size: CGSize) -> UIImage? {
        guard let img = scene.back else { return nil }
        let key = "\(scene.id)-\(Int(size.width))x\(Int(size.height))-\(scene.anchor)"
        if let hit = backs[key] { return hit }
        let k = max(size.width / img.size.width, size.height / img.size.height)
        let w = img.size.width * k, h = img.size.height * k
        let out = UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) * scene.anchor, width: w, height: h))
        }
        backs[key] = out
        return out
    }

    static func glyphs(_ theme: ThemeSet) -> [UIImage] {
        let key = "\(theme.name)-\(theme.background.glyphs)-\(theme.background.tint)"
        if let hit = glyphs[key] { return hit }
        let side: CGFloat = 160
        let out = theme.background.glyphs.map { g in
            UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: side * 0.9), .foregroundColor: theme.background.tint.uiColor]
                let str = NSAttributedString(string: String(g), attributes: attrs)
                let b = str.size()
                str.draw(at: CGPoint(x: (side - b.width) / 2, y: (side - b.height) / 2))
            }
        }
        glyphs[key] = out
        return out
    }
}

struct ThemeBackgroundView: View {
    var theme: ThemeSet = .named(nil)
    var scene = BackgroundScene()
    // Figures are for the screens away from play; a table shows only the picture behind.
    var figures = true
    // One clock for every background, so a screen that redraws often does not restart the drift.
    private static let epoch = Date()

    var body: some View {
        let style = theme.background
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(Self.epoch)
            Canvas { ctx, size in
                let full = Path(CGRect(origin: .zero, size: size))
                ctx.fill(full, with: .color(Color(theme.colour.background)))
                if let back = Prerendered.back(scene, size: size) {
                    ctx.draw(Image(uiImage: back), in: CGRect(origin: .zero, size: size))
                }
                let light = BackgroundMath.flicker(style, t)
                let glyphs = Prerendered.glyphs(theme)
                if !glyphs.isEmpty {
                    for p in BackgroundMath.particles {
                        guard let f = BackgroundMath.glyphFrame(p, style: style, t: t * style.speed, light: light, width: size.width, height: size.height) else { continue }
                        ctx.drawLayer { layer in
                            layer.opacity = f.alpha
                            layer.translateBy(x: f.x, y: f.y)
                            layer.rotate(by: .degrees(f.rotationDegrees))
                            layer.draw(Image(uiImage: glyphs[p.glyphIndex % glyphs.count]), in: CGRect(x: -f.size / 2, y: -f.size / 2, width: f.size, height: f.size))
                        }
                    }
                }
                for sp in BackgroundMath.specks.prefix(style.specks) {
                    let s = BackgroundMath.speckFrame(sp, style: style, t: t, width: size.width, height: size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: s.x - s.radius, y: s.y - s.radius, width: s.radius * 2, height: s.radius * 2)), with: .color(Color(style.speckColour).opacity(s.alpha)))
                }
                let glow = Color(style.glow)
                let centre = style.glowFromTop ? CGPoint(x: size.width * 0.5, y: -size.height * 0.1) : CGPoint(x: size.width * 0.5, y: size.height * 1.05)
                ctx.fill(full, with: .radialGradient(Gradient(colors: [glow.opacity(0.22 * light), glow.opacity(0.08 * light), .clear]), center: centre, startRadius: 0, endRadius: size.height * 0.9))
                ctx.fill(full, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.75)]), center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0, endRadius: max(size.width, size.height) * 0.75))
                if figures, let front = scene.front {
                    for f in scene.fronts { figure(front, f, ctx: ctx, size: size) }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func figure(_ img: UIImage, _ f: SceneFront, ctx: GraphicsContext, size: CGSize) {
        let k = min(f.h * size.height / img.size.height, f.maxW * size.width / img.size.width)
        let w = img.size.width * k, h = img.size.height * k
        let x = f.at == .bottomRight ? size.width - w : 0
        let y = f.at == .topLeft ? 0 : size.height - h
        var c = ctx
        c.translateBy(x: x + w / 2, y: y + h / 2)
        c.scaleBy(x: f.flipX ? -1 : 1, y: f.flipY ? -1 : 1)
        c.draw(Image(uiImage: img), in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
    }
}
#endif
