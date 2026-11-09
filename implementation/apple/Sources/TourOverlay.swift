#if canImport(UIKit)
import SwiftUI

// Where each element a step can ring sits on screen. Mark an element with `.tourAnchor("name")`.
struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    // Added to the anchors from inside, so a part inside another part is found too.
    func tourAnchor(_ name: String) -> some View {
        transformAnchorPreference(key: TourAnchorKey.self, value: .bounds) { value, anchor in value[name] = anchor }
    }

    // An anchor on one of several alike views, such as the first of a list.
    @ViewBuilder func tourAnchor(_ name: String, if condition: Bool) -> some View {
        if condition { tourAnchor(name) } else { self }
    }
}

// The three button texts, already translated.
struct TourButtons {
    var next: String
    var skip: String
    var done: String
}

// A lesson over the screen, one step at a time: a circle of light on the step's element with the rest
// dimmed, and a card on the other half with the sentence, Skip and Next, or the done text at the end.
// Put it where the tour should cover, with `.overlayPreferenceValue(TourAnchorKey.self)`.
struct TourOverlay: View {
    let view: TourView
    let anchors: [String: Anchor<CGRect>]
    let buttons: TourButtons
    let onNext: () -> Void
    let onSkip: () -> Void
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        // Laid out in the safe area, so the card keeps clear of the camera and the home indicator;
        // the dim reaches past it to the screen's edges.
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            let screen = CGRect(x: -insets.leading, y: -insets.top, width: size.width + insets.leading + insets.trailing, height: size.height + insets.top + insets.bottom)
            let circle = anchors[view.anchor].flatMap { ring(proxy[$0], on: screen) }
            let below = TourModel.cardBelow(circle.map { TourCircle(x: $0.midX, y: $0.midY, r: $0.width / 2) }, viewportHeight: Double(size.height))
            let primary = Color(theme.colour.primary)
            ZStack {
                Color.clear.contentShape(Rectangle()).onTapGesture {}.ignoresSafeArea()
                Path { p in
                    p.addRect(screen.insetBy(dx: -40, dy: -40))
                    if let circle { p.addEllipse(in: circle) }
                }
                .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
                if let circle {
                    Circle().stroke(primary.opacity(0.85), lineWidth: 2)
                        .frame(width: circle.width, height: circle.height)
                        .position(x: circle.midX, y: circle.midY)
                        .allowsHitTesting(false)
                }
                VStack {
                    if below { Spacer() }
                    card
                    if !below { Spacer() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .animation(.easeInOut(duration: 0.25), value: view.step)
        }
        .id(view.lessonId)
    }

    // The circle round an element, clipped to the screen; none when it is off screen.
    private func ring(_ r: CGRect, on screen: CGRect) -> CGRect? {
        let c = r.intersection(screen)
        guard !c.isNull, c.width > 0, c.height > 0 else { return nil }
        let radius = max(28, hypot(c.width, c.height) / 2 + 8)
        return CGRect(x: c.midX - radius, y: c.midY - radius, width: radius * 2, height: radius * 2)
    }

    private var card: some View {
        let primary = Color(theme.colour.primary)
        return VStack(alignment: .leading, spacing: 8) {
            Text(view.title).font(.headline).foregroundStyle(primary)
            Text(view.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if view.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<view.count, id: \.self) { i in Circle().fill(i == view.step ? primary : Color.white.opacity(0.3)).frame(width: 6, height: 6) }
                }
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: 8) {
                if !view.last {
                    Button(buttons.skip, action: onSkip).foregroundStyle(primary).padding(.horizontal, 8)
                }
                Button(action: onNext) {
                    Text(view.last ? buttons.done : buttons.next).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(theme.colour.surface).opacity(0.97), in: RoundedRectangle(cornerRadius: 16))
        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(theme.colour.edge), lineWidth: 1))
        .phoneColumn()
    }
}

// Shows the tour's current step over whatever it covers and keeps itself up to date.
struct TourHost: ViewModifier {
    let tour: Tour
    let buttons: TourButtons
    @State private var view: TourView?

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TourAnchorKey.self) { anchors in
                if let view {
                    TourOverlay(view: view, anchors: anchors, buttons: buttons, onNext: { tour.next() }, onSkip: { tour.skip() })
                }
            }
            .onAppear {
                view = tour.current
                tour.onChange { view = $0 }
            }
    }
}

extension View {
    func tourHost(_ tour: Tour, buttons: TourButtons) -> some View { modifier(TourHost(tour: tour, buttons: buttons)) }
}
#endif
