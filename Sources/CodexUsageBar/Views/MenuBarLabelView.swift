import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: RateLimitSnapshot?
    let isStale: Bool

    var body: some View {
        if let primary = snapshot?.primary {
            HStack(spacing: 3) {
                Text("\(primary.remainingPercent)% \(UsageFormatting.resetTime(primary.resetsAt))")
                    .monospacedDigit()

                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityLabel("用量数据可能已过期")
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        } else {
            Text("--% --")
                .monospacedDigit()
        }
    }
}
