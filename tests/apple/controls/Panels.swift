#if canImport(UIKit)
import SwiftUI

extension View {
    // Lists and forms keep a phone's width in the middle of a wide screen. On tvOS an optional help
    // button (`help`, with its already translated `helpLabel`) sits under the content.
    @ViewBuilder func phoneColumn(help: (() -> Void)? = nil, helpLabel: String = "") -> some View {
        #if os(tvOS)
        VStack(spacing: 12) {
            self
            if let help {
                Button(action: help) { Label(helpLabel, systemImage: "lightbulb.fill").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
            }
        }.frame(maxWidth: 560).frame(maxWidth: .infinity).focusSection()
        #else
        frame(maxWidth: 560).frame(maxWidth: .infinity)
        #endif
    }
}

// A rounded panel that groups related content; nest for sub-sections. An active panel is where the
// next tap belongs: primary edge, lighter fill.
struct Panel<Content: View>: View {
    var title: String? = nil
    var active = false
    @ViewBuilder let content: () -> Content
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        let primary = Color(theme.colour.primary)
        let radius = theme.radii.lg
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if let title { Text(title).font(.headline).foregroundStyle(primary) }
            content()
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: radius))
        .background(active ? primary.opacity(0.12) : Color(theme.colour.surface), in: RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(active ? primary : Color(theme.colour.edge), lineWidth: active ? 2 : 1))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }
}

// The accent instruction line, in its own slim banner, with optional controls at its end.
struct PromptBanner<Trailing: View>: View {
    let text: String
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.controlsTheme) private var theme

    init(_ text: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.subheadline.bold()).foregroundStyle(Color(theme.colour.primary))
            Spacer()
            trailing()
        }
        .padding(.leading, theme.spacing.lg).padding(.trailing, theme.spacing.sm).padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: theme.radii.lg))
        .background(Color(theme.colour.surface), in: RoundedRectangle(cornerRadius: theme.radii.lg))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.lg).stroke(Color(theme.colour.edge), lineWidth: 1))
    }
}
#endif
