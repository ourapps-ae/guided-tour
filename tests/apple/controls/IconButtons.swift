#if canImport(UIKit)
import SwiftUI

// An icon with a small badge in the corner, such as a plus on a robot for "add a computer player".
struct BadgedIcon: View {
    let path: String
    let tint: Color
    var badge = "plus"
    var size: CGFloat = 22
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        SVGIcon(d: path).fill(tint).frame(width: size, height: size)
            .overlay(alignment: .topTrailing) {
                Image(systemName: badge).font(.system(size: size * 0.36, weight: .heavy)).foregroundStyle(Color(theme.colour.onPrimary))
                    .frame(width: size * 0.6, height: size * 0.6).background(tint, in: Circle()).offset(x: size * 0.27, y: -size * 0.23)
            }
    }
}

// Going back up a level: the leave icon turned to point left. Back is always on the left and
// going deeper in on the right.
struct BackGlyph: View {
    let tint: Color
    var body: some View { Image(systemName: "rectangle.portrait.and.arrow.right").foregroundStyle(tint).rotationEffect(.degrees(180)) }
}

// A round icon button: filled for the main action, outlined for the others. `glyph` draws the icon in
// the colour it is given. `glow` pulses a halo while enabled.
struct RoundIconButton<Glyph: View>: View {
    let label: String
    let enabled: Bool
    let filled: Bool
    var glow = false
    let action: () -> Void
    @ViewBuilder let glyph: (Color) -> Glyph
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        let primary = Color(theme.colour.primary)
        let fg = filled ? Color(theme.colour.onPrimary) : primary
        Button(action: action) {
            glyph(fg)
                .frame(width: 40, height: 40)
                .background(filled ? (enabled ? primary : primary.opacity(0.45)) : .clear, in: Circle())
                .overlay(Circle().stroke(filled ? .clear : primary.opacity(0.5), lineWidth: 1))
                .opacity(enabled ? 1 : (filled ? 0.7 : 0.4))
                .contentShape(Circle())
        }
        .controlButtonStyle()
        .disabled(!enabled)
        .pulseHalo(glow && enabled, cornerRadius: 20)
        .accessibilityLabel(label)
    }
}

// An icon in the corner of a screen that opens help, with the whole 40 pt square taking the tap.
struct HelpBulb: View {
    let label: String
    let action: () -> Void
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        Button(action: action) {
            SVGIcon(d: IconPath.bulb).fill(Color(theme.colour.primary)).frame(width: 24, height: 24).frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .controlButtonStyle()
        .accessibilityLabel(label)
    }
}

// A round on/off switch (microphone, camera, sound): filled when on, struck through when off.
// Icon names are SF Symbols.
struct ToggleButton: View {
    let on: Bool
    let onIcon: String
    let offIcon: String
    let label: String
    var enabled = true
    let action: () -> Void
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        let primary = Color(theme.colour.primary)
        Button(action: action) {
            Image(systemName: on ? onIcon : offIcon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(on ? primary : .white)
                .background(on ? primary.opacity(0.25) : Color(theme.colour.danger).opacity(0.45), in: Circle())
        }
        .controlButtonStyle()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
#endif
