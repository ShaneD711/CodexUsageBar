import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: RateLimitSnapshot?
    let isStale: Bool
    let localization: AppLocalization

    var body: some View {
        if let primary = snapshot?.primary {
            HStack(spacing: 3) {
                Text("\(primary.remainingPercent)% \(UsageFormatting.resetTime(primary.resetsAt))")
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
