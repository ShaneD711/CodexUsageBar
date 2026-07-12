import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: RateLimitSnapshot?
    let isStale: Bool
    let localization: AppLocalization

    var body: some View {
        if let window = snapshot?.menuBarWindow {
            HStack(spacing: 3) {
                Text(
                    "\(window.remainingPercent)% "
                        + UsageFormatting.resetText(for: window)
                )
                    .monospacedDigit()

                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityLabel(localization.staleAccessibilityLabel)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        } else {
            Text("--% --")
                .monospacedDigit()
        }
    }
}
