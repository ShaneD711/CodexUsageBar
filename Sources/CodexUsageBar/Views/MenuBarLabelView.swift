import SwiftUI

struct MenuBarLabelView: View {
    let snapshot: RateLimitSnapshot?

    var body: some View {
        if let primary = snapshot?.primary {
            Text("\(primary.remainingPercent)% \(UsageFormatting.resetTime(primary.resetsAt))")
                .monospacedDigit()
        } else {
            Text("--% --")
                .monospacedDigit()
        }
    }
}
