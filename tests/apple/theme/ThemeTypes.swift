import Foundation

// The token shapes ThemeTokens.swift (generated from themes.json) fills in. No UI framework here,
// so the values can be read and tested anywhere; ThemeBackgroundView.swift turns them into Colors.
struct ThemeColour: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    // 0xRRGGBBAA.
    init(rgba: UInt32) {
        red = Double((rgba >> 24) & 0xFF) / 255
        green = Double((rgba >> 16) & 0xFF) / 255
        blue = Double((rgba >> 8) & 0xFF) / 255
        alpha = Double(rgba & 0xFF) / 255
    }

    // An installer colour: "hex e0b35a" (an aepm string setting cannot hold "#" and starts with a
    // letter), "#rrggbb", "rrggbb", each optionally with two more digits of opacity; nil for anything else.
    static func setting(_ value: String) -> ThemeColour? {
        var text = value.trimmingCharacters(in: .whitespaces)
        if text.lowercased().hasPrefix("hex") {
            let rest = text.dropFirst(3)
            guard rest.first == " " || rest.first == "\t" else { return nil }
            text = rest.trimmingCharacters(in: .whitespaces)
        }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, text.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
        return ThemeColour(hex: "#" + text)
    }

    // "#rrggbb" or "#rrggbbaa"; nil for anything else.
    init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 || hex.count == 9, let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(rgba: hex.count == 7 ? (value << 8) | 0xFF : value)
    }
}

struct ThemeColours: Equatable {
    var background, surface, edge, primary, onPrimary, table, tableEdge, text, muted, danger, good, warning, paper, paperAccent: ThemeColour
}

struct ThemeSpacing { let xs, sm, md, lg, xl: Double }
struct ThemeRadii { let sm, md, lg, pill: Double }
struct ThemeType { let family: String; let caption, small, body, subtitle, title, display: Double }

struct ThemeBackgroundStyle {
    let tint: ThemeColour
    let glow: ThemeColour
    let glowFromTop: Bool
    let speed: Double
    let suitAlpha: Double
    let specks: Int
    let speckUp: Bool
    let speckColour: ThemeColour
    let glyphs: String
}

struct ThemeSet {
    let name: String
    var colour: ThemeColours
    let spacing: ThemeSpacing
    let radii: ThemeRadii
    let type: ThemeType
    let background: ThemeBackgroundStyle

    // The named theme, the default when the name is unknown or nil.
    static func named(_ name: String?) -> ThemeSet {
        ThemeTokens.all[name ?? ""] ?? ThemeTokens.all[ThemeTokens.defaultName]!
    }

    // The colour apple-host passes as ShellConfiguration.tint.
    var accent: ThemeColour { colour.primary }

    // The installer's colour overrides (see ThemeColour.setting); an empty or malformed value is ignored.
    func resolved(primary: String? = nil, table: String? = nil) -> ThemeSet {
        var out = self
        if let primary, let c = ThemeColour.setting(primary) { out.colour.primary = c }
        if let table, let c = ThemeColour.setting(table) { out.colour.table = c }
        return out
    }
}
