#if canImport(UIKit)
import SwiftUI

// Pulsing white halo behind anything the person may tap right now. The one visual rule for
// "this is a choice": if it glows, you can tap it.
struct PulseHalo: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat?
    @State private var pulse = false

    func body(content: Content) -> some View {
        content.background {
            if active {
                Group {
                    if let r = cornerRadius {
                        RoundedRectangle(cornerRadius: r + 6).fill(Color.white.opacity(pulse ? 0.55 : 0.2)).padding(-6)
                    } else {
                        Circle().fill(Color.white.opacity(pulse ? 0.55 : 0.2)).padding(-6)
                    }
                }
                .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true } }
                .onDisappear { pulse = false }
            }
        }
    }
}

extension View {
    func pulseHalo(_ active: Bool, cornerRadius: CGFloat? = nil) -> some View { modifier(PulseHalo(active: active, cornerRadius: cornerRadius)) }
}
#endif
