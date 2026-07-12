import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation

    var body: some View {
        Text(presentation.displayText)
            .monospacedDigit()
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: presentation.labelWidth, alignment: .center)
            .accessibilityLabel(presentation.accessibilityLabel)
            .help(presentation.tooltip)
            .fixedSize(horizontal: true, vertical: false)
    }
}
