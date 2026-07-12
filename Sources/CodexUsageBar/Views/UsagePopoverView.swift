import AppKit
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    let localization: AppLocalization
    @State private var copiedDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, PopoverMetrics.headerBottomInset)
            Divider()
            usageContent
                .padding(.vertical, PopoverMetrics.sectionInset)
            Divider()
            footer
                .padding(.top, PopoverMetrics.footerTopInset)
        }
        .font(.body)
        .padding(PopoverMetrics.outerInset)
        .frame(width: PopoverMetrics.width)
        .task {
            await store.refresh()
        }
    }

    private var header: some View {
        HStack {
            Text(localization.headerTitle)
                .font(.headline)

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var usageContent: some View {
        if let snapshot = store.snapshot {
            VStack(spacing: PopoverMetrics.usageRowSpacing) {
                ForEach(Array(snapshot.windows.enumerated()), id: \.offset) { _, window in
                    UsageWindowRow(
                        title: localization.windowTitle(durationMinutes: window.durationMinutes),
                        window: window,
                        resetText: UsageFormatting.resetText(for: window)
                    )
                }
            }
        } else {
            Text(emptyStateMessage)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: PopoverMetrics.actionSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                if let snapshot = store.snapshot {
                    HStack(spacing: 4) {
                        if store.isSnapshotStale {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }

                        Text(statusText(for: snapshot))
                    }
                    .foregroundStyle(store.isSnapshotStale ? Color.orange : Color.secondary)
                } else {
                    Text("\(localization.notRefreshed) · v\(AppSupport.version)")
                        .foregroundStyle(.secondary)
                }

                if let failure = store.lastFailure, store.snapshot != nil {
                    Text(localization.cachedFailure(localization.failureMessage(failure)))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            Spacer()

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(store.isRefreshing)
            .help(localization.refresh)

            Menu {
                Button {
                    if let applicationURL = AppSupport.runningApplicationURL {
                        AppSupport.revealInFinder(applicationURL)
                    }
                } label: {
                    Label(localization.showInFinder, systemImage: "folder")
                }
                .disabled(AppSupport.runningApplicationURL == nil)

                Button {
                    copyDiagnostics()
                } label: {
                    Label(
                        copiedDiagnostics ? localization.copied : localization.copyDiagnostics,
                        systemImage: copiedDiagnostics ? "checkmark" : "doc.on.doc"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .controlSize(.small)
            .fixedSize()
            .help(localization.more)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(localization.quit)
        }
    }

    private var emptyStateMessage: String {
        guard let failure = store.lastFailure else {
            return localization.readingUsage
        }
        return localization.failureMessage(failure)
    }

    private func statusText(for snapshot: RateLimitSnapshot) -> String {
        let lastUpdated = UsageFormatting.lastUpdated(
            snapshot.fetchedAt,
            localization: localization
        )
        let status = store.isSnapshotStale
            ? localization.staleStatus(lastUpdated: lastUpdated)
            : lastUpdated
        return "\(status) · v\(AppSupport.version)"
    }

    private func copyDiagnostics() {
        let snapshotState: AppDiagnostics.SnapshotState
        if store.snapshot == nil {
            snapshotState = .unavailable
        } else if store.isSnapshotStale {
            snapshotState = .availableStale
        } else {
            snapshotState = .availableFresh
        }

        let diagnostics = AppDiagnostics(
            appVersion: AppSupport.version,
            operatingSystem: AppSupport.operatingSystem,
            architecture: AppSupport.architecture,
            executable: store.resolvedExecutable,
            snapshotState: snapshotState,
            lastRefresh: store.snapshot?.fetchedAt,
            lastFailure: store.lastFailure
        )
        AppSupport.copyToPasteboard(AppSupport.diagnosticReport(diagnostics))
        copiedDiagnostics = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copiedDiagnostics = false
        }
    }
}

private struct UsageWindowRow: View {
    let title: String
    let window: RateLimitWindow
    let resetText: String

    var body: some View {
        VStack(spacing: PopoverMetrics.labelToProgressSpacing) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(window.remainingPercent)%")
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Text(resetText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: PopoverMetrics.resetColumnWidth, alignment: .trailing)
            }

            ProgressView(value: Double(window.remainingPercent), total: 100)
                .progressViewStyle(.linear)
                .controlSize(.small)
        }
    }
}

private enum PopoverMetrics {
    static let width: CGFloat = 320
    static let outerInset: CGFloat = 12
    static let headerBottomInset: CGFloat = 10
    static let sectionInset: CGFloat = 12
    static let footerTopInset: CGFloat = 8
    static let usageRowSpacing: CGFloat = 14
    static let labelToProgressSpacing: CGFloat = 6
    static let actionSpacing: CGFloat = 8
    static let resetColumnWidth: CGFloat = 52
}
