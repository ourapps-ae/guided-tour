#if canImport(UIKit)
import SwiftUI

// One titled section of a help page; text is already translated.
struct HelpSection: Identifiable {
    let title: String
    let body: String
    var id: String { title + body }
}

// A scrolling help page: a heading with a close button, titled sections and a footer line.
struct HelpPage: View {
    let title: String
    let sections: [HelpSection]
    var footer: String? = nil
    let closeLabel: String
    let onClose: () -> Void
    @Environment(\.controlsTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.title.bold())
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark").font(.title3) }
                        .accessibilityLabel(closeLabel)
                }
                ForEach(sections) { section in
                    Text(section.title).font(.headline).foregroundStyle(Color(theme.colour.primary)).padding(.top, 8)
                    Text(section.body)
                }
                if let footer { Text(footer).font(.footnote).foregroundStyle(.secondary).padding(.top, 16) }
            }
            .padding(24)
            .phoneColumn()
        }
    }
}
#endif
