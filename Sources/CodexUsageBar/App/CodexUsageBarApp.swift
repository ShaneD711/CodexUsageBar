import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CodexUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore()
    private let localization = AppLocalization.current

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(store: store, localization: localization)
        } label: {
            MenuBarLabelView(
                snapshot: store.snapshot,
                isStale: store.isSnapshotStale,
                localization: localization
            )
        }
        .menuBarExtraStyle(.window)
    }
}
