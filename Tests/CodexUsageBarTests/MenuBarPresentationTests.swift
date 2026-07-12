import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import CodexUsageBar

final class MenuBarPresentationTests: XCTestCase {
    func testStandardIsTheDefaultForMissingOrInvalidStoredValues() {
        XCTAssertEqual(MenuBarDisplayMode.resolve(storedValue: nil), .standard)
        XCTAssertEqual(MenuBarDisplayMode.resolve(storedValue: ""), .standard)
        XCTAssertEqual(MenuBarDisplayMode.resolve(storedValue: "rich"), .standard)
        XCTAssertEqual(MenuBarDisplayMode.resolve(storedValue: "compact"), .compact)
    }

    func testStandardPresentationIncludesPercentageAndResetTime() {
        let presentation = MenuBarPresentationBuilder.build(
            snapshot: makeSnapshot(usedPercent: 19),
            availability: .availableFresh,
            mode: .standard,
            localization: AppLocalization(language: .english),
            resetTextProvider: { _ in "16:35" }
        )

        XCTAssertEqual(presentation.displayText, "81% 16:35")
        XCTAssertFalse(presentation.displayText.contains("!"))
        XCTAssertEqual(presentation.labelWidth, 82)
        XCTAssertFalse(presentation.showsStaleWarning)
        XCTAssertEqual(presentation.tooltip, "Codex usage remaining: 81%, resets at 16:35")
        XCTAssertEqual(presentation.accessibilityLabel, presentation.tooltip)
        XCTAssertEqual(presentation.mode, .standard)
    }

    func testCompactPresentationOmitsResetTime() {
        let presentation = MenuBarPresentationBuilder.build(
            snapshot: makeSnapshot(usedPercent: 19),
            availability: .availableFresh,
            mode: .compact,
            localization: AppLocalization(language: .english),
            resetTextProvider: { _ in "16:35" }
        )

        XCTAssertEqual(presentation.displayText, "81%")
        XCTAssertFalse(presentation.displayText.contains("!"))
        XCTAssertEqual(presentation.labelWidth, 44)
        XCTAssertEqual(presentation.tooltip, "Codex usage remaining: 81%")
        XCTAssertEqual(presentation.mode, .compact)
    }

    func testMissingDataUsesPlaceholdersInsteadOfZero() {
        let localization = AppLocalization(language: .english)
        let standard = MenuBarPresentationBuilder.build(
            snapshot: nil,
            availability: .loading,
            mode: .standard,
            localization: localization
        )
        let compact = MenuBarPresentationBuilder.build(
            snapshot: nil,
            availability: .loading,
            mode: .compact,
            localization: localization
        )

        XCTAssertEqual(standard.displayText, "--% --")
        XCTAssertEqual(standard.labelWidth, 82)
        XCTAssertFalse(standard.displayText.contains("0%"))
        XCTAssertEqual(compact.displayText, "--%")
        XCTAssertEqual(compact.labelWidth, 44)
        XCTAssertFalse(compact.displayText.contains("0%"))
    }

    func testStalePresentationKeepsTheLastSuccessfulValues() {
        let presentation = MenuBarPresentationBuilder.build(
            snapshot: makeSnapshot(usedPercent: 47),
            availability: .availableStale,
            mode: .standard,
            localization: AppLocalization(language: .simplifiedChinese),
            resetTextProvider: { _ in "19:05" }
        )

        XCTAssertEqual(presentation.displayText, "53% 19:05 !")
        XCTAssertTrue(presentation.displayText.contains("!"))
        XCTAssertTrue(presentation.showsStaleWarning)
        XCTAssertEqual(
            presentation.tooltip,
            "Codex 剩余用量：53%，重置时间 19:05。用量数据可能已过期"
        )
        XCTAssertEqual(presentation.accessibilityLabel, presentation.tooltip)
    }

    func testLongResetTimeUsesTheWiderStandardWidthBucket() {
        let presentation = MenuBarPresentationBuilder.build(
            snapshot: makeSnapshot(usedPercent: 19),
            availability: .availableFresh,
            mode: .standard,
            localization: AppLocalization(language: .english),
            resetTextProvider: { _ in "4:35 PM" }
        )

        XCTAssertEqual(presentation.displayText, "81% 4:35 PM")
        XCTAssertEqual(presentation.labelWidth, 104)
    }

    func testUnavailableStateUsesStableLocalizedDescription() {
        let presentation = MenuBarPresentationBuilder.build(
            snapshot: nil,
            availability: .notLoggedIn,
            mode: .compact,
            localization: AppLocalization(language: .english)
        )

        XCTAssertEqual(presentation.availability, .notLoggedIn)
        XCTAssertEqual(presentation.displayText, "--%")
        XCTAssertEqual(
            presentation.tooltip,
            "Codex is not signed in. Open Codex and sign in first."
        )
        XCTAssertEqual(presentation.accessibilityLabel, presentation.tooltip)
    }

    @MainActor
    func testRenderedWidthStaysStableWithinEachDisplayMode() {
        let standardWidths = [
            renderedWidth(usedPercent: 91, resetTime: "8:05", isStale: false, mode: .standard),
            renderedWidth(usedPercent: 0, resetTime: "20:35", isStale: true, mode: .standard),
        ]
        let compactWidths = [
            renderedWidth(usedPercent: 91, resetTime: nil, isStale: false, mode: .compact),
            renderedWidth(usedPercent: 0, resetTime: nil, isStale: true, mode: .compact),
        ]

        XCTAssertEqual(Set(standardWidths).count, 1, "Standard widths: \(standardWidths)")
        XCTAssertEqual(Set(compactWidths).count, 1, "Compact widths: \(compactWidths)")
        XCTAssertGreaterThan(standardWidths[0], compactWidths[0])
    }

    private func makeSnapshot(usedPercent: Double) -> RateLimitSnapshot {
        RateLimitSnapshot(
            primary: RateLimitWindow(
                usedPercent: usedPercent,
                durationMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 1_783_756_800)
            ),
            secondary: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_783_753_200)
        )
    }

    @MainActor
    private func renderedWidth(
        usedPercent: Double?,
        resetTime: String?,
        isStale: Bool,
        mode: MenuBarDisplayMode
    ) -> CGFloat {
        let presentation = MenuBarPresentationBuilder.build(
            snapshot: usedPercent.map(makeSnapshot),
            availability: isStale ? .availableStale : .availableFresh,
            mode: mode,
            localization: AppLocalization(language: .english),
            resetTextProvider: { _ in resetTime ?? "--" }
        )
        let view = MenuBarLabelView(presentation: presentation)
        return NSHostingView(rootView: view).fittingSize.width
    }
}
