#if canImport(UIKit)
import SwiftUI

// A shape from Material icon path data, scaled from its 24 x 24 box to fit the frame.
struct SVGIcon: Shape {
    let d: String

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for command in SVGPath.parse(d) ?? [] {
            switch command {
            case let .move(x, y): p.move(to: CGPoint(x: x, y: y))
            case let .line(x, y): p.addLine(to: CGPoint(x: x, y: y))
            case let .curve(c1x, c1y, c2x, c2y, x, y): p.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
            case .close: p.closeSubpath()
            }
        }
        let s = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(translationX: rect.midX - 12 * s, y: rect.midY - 12 * s).scaledBy(x: s, y: s))
    }
}
#endif
