import AppKit
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            usageContent
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .task {
            await store.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex")
                    .font(.headline)
                Text("剩余用量")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
            VStack(spacing: 12) {
                UsageWindowRow(
                    title: "5 小时",
                    window: snapshot.primary,
                    resetText: UsageFormatting.resetTime(snapshot.primary.resetsAt)
                )

                if let secondary = snapshot.secondary {
                    UsageWindowRow(
                        title: "1 周",
                        window: secondary,
                        resetText: UsageFormatting.resetDate(secondary.resetsAt)
                    )
                }
            }
        } else {
            Text(store.errorMessage ?? "正在读取 Codex 用量…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let snapshot = store.snapshot {
                    HStack(spacing: 4) {
                        if store.isSnapshotStale {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }

                        Text(
                            store.isSnapshotStale
                                ? "数据可能已过期 · \(UsageFormatting.lastUpdated(snapshot.fetchedAt))"
                                : UsageFormatting.lastUpdated(snapshot.fetchedAt)
                        )
                    }
                    .foregroundStyle(store.isSnapshotStale ? Color.orange : Color.secondary)
                } else {
                    Text("尚未刷新")
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = store.errorMessage, store.snapshot != nil {
                    Text("\(errorMessage) 正在显示上次数据。")
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
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .help("刷新")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("退出")
        }
    }
}

private struct UsageWindowRow: View {
    let title: String
    let window: RateLimitWindow
    let resetText: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))

                Spacer()

                Text("\(window.remainingPercent)%")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()

                Text(resetText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 54, alignment: .trailing)
            }

            ProgressView(value: Double(window.remainingPercent), total: 100)
                .progressViewStyle(.linear)
        }
    }
}
