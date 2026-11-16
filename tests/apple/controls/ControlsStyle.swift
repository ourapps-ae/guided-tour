#if canImport(UIKit)
import SwiftUI

// The theme the controls draw with; set once near the top of the view tree.
private struct ControlsThemeKey: EnvironmentKey {
    static let defaultValue = ThemeSet.named(nil)
}

extension EnvironmentValues {
    var controlsTheme: ThemeSet {
        get { self[ControlsThemeKey.self] }
        set { self[ControlsThemeKey.self] = newValue }
    }
}

extension View {
    func controlsTheme(_ theme: ThemeSet) -> some View { environment(\.controlsTheme, theme) }

    // Plain buttons everywhere; the bordered style on tvOS, where focus needs a visible shape.
    @ViewBuilder func controlButtonStyle() -> some View {
        #if os(tvOS)
        buttonStyle(.bordered)
        #else
        buttonStyle(.plain)
        #endif
    }
}
#endif
