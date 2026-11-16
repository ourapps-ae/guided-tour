import Foundation

// One step of an outline in a 24 x 24 box, absolute coordinates.
enum SVGPathCommand: Equatable {
    case move(Double, Double)
    case line(Double, Double)
    case curve(c1x: Double, c1y: Double, c2x: Double, c2y: Double, x: Double, y: Double)
    case close
}

// Path data written with M L H V C S Z, absolute or relative, as the Material icons are.
// nil when it holds anything else (so a new icon with arcs is noticed, not drawn wrongly).
enum SVGPath {
    // Letters, and numbers with an optional sign, a fraction, and no separator needed before a
    // sign or a second decimal point ("1.5-.5" is 1.5 and -.5, ".5.5" is .5 and .5).
    static func tokenise(_ d: String) -> [String]? {
        var tokens: [String] = []
        var number = ""
        func flush() { if !number.isEmpty { tokens.append(number); number = "" } }
        for ch in d {
            if ch.isLetter { flush(); tokens.append(String(ch)) }
            else if ch == "-" { flush(); number = "-" }
            else if ch == "." { if number.contains(".") { flush() }; number.append(ch) }
            else if ch.isASCII && ch.isNumber { number.append(ch) }
            else if ch == " " || ch == "," || ch == "\n" || ch == "\t" { flush() }
            else { return nil }
        }
        flush()
        return tokens
    }

    static func parse(_ d: String) -> [SVGPathCommand]? {
        guard let tokens = tokenise(d) else { return nil }
        var out: [SVGPathCommand] = []
        var i = 0
        var cmd: Character = "M"
        var cur = (x: 0.0, y: 0.0), start = (x: 0.0, y: 0.0)
        var lastControl: (x: Double, y: Double)?
        func num() -> Double? {
            guard i < tokens.count, let v = Double(tokens[i]) else { return nil }
            i += 1
            return v
        }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter {
                guard "MmLlHhVvCcSsZz".contains(c) else { return nil }
                cmd = c
                i += 1
                if c == "Z" || c == "z" { out.append(.close); cur = start; lastControl = nil; continue }
            }
            let rel = cmd.isLowercase
            let ox = rel ? cur.x : 0, oy = rel ? cur.y : 0
            switch cmd {
            case "M", "m":
                guard let x = num(), let y = num() else { return nil }
                cur = (ox + x, oy + y); start = cur; out.append(.move(cur.x, cur.y))
                cmd = rel ? "l" : "L"; lastControl = nil
            case "L", "l":
                guard let x = num(), let y = num() else { return nil }
                cur = (ox + x, oy + y); out.append(.line(cur.x, cur.y)); lastControl = nil
            case "H", "h":
                guard let x = num() else { return nil }
                cur.x = ox + x; out.append(.line(cur.x, cur.y)); lastControl = nil
            case "V", "v":
                guard let y = num() else { return nil }
                cur.y = oy + y; out.append(.line(cur.x, cur.y)); lastControl = nil
            case "C", "c":
                guard let a = num(), let b = num(), let c = num(), let d = num(), let e = num(), let f = num() else { return nil }
                let c2 = (x: ox + c, y: oy + d), end = (x: ox + e, y: oy + f)
                out.append(.curve(c1x: ox + a, c1y: oy + b, c2x: c2.x, c2y: c2.y, x: end.x, y: end.y)); lastControl = c2; cur = end
            case "S", "s":
                guard let c = num(), let d = num(), let e = num(), let f = num() else { return nil }
                let c1 = lastControl.map { (x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = (x: ox + c, y: oy + d), end = (x: ox + e, y: oy + f)
                out.append(.curve(c1x: c1.x, c1y: c1.y, c2x: c2.x, c2y: c2.y, x: end.x, y: end.y)); lastControl = c2; cur = end
            default:
                return nil
            }
        }
        return out
    }
}
