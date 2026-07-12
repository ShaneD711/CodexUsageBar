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
    @AppStorage(MenuBarDisplayMode.storageKey) private var storedDisplayMode = MenuBarDisplayMode.standard.rawValue
    private let localization = AppLocalization.current

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(
                store: store,
                localization: localization,
                displayMode: displayModeBinding
            )
        } label: {
            MenuBarLabelView(
                presentation: MenuBarPresentationBuilder.build(
                    snapshot: store.snapshot,
                    availability: store.availability,
                    mode: displayMode,
                    localization: localization
                )
            )
        }
        .menuBarExtraStyle(.window)
    }

    private var displayMode: MenuBarDisplayMode {
        MenuBarDisplayMode.resolve(storedValue: storedDisplayMode)
    }

    private var displayModeBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { displayMode },
            set: { storedDisplayMode = $0.rawValue }
        )
    }
}
