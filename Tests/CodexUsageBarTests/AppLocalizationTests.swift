import Foundation
import XCTest
@testable import CodexUsageBar

final class AppLocalizationTests: XCTestCase {
    func testChineseLanguageIdentifiersSelectSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hans"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-SG"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh_CN"]), .simplifiedChinese)
    }

    func testTraditionalChineseEnglishAndUnknownLanguagesUseEnglish() {
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hant"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hant-CN"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-TW"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-HK"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["ja-JP"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: []), .english)
    }

    func testRelativeTimeUsesSelectedLanguage() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let now = date.addingTimeInterval(5 * 60)

        XCTAssertEqual(
            UsageFormatting.lastUpdated(date, now: now, localization: AppLocalization(language: .simplifiedChinese)),
            "5 分钟前刷新"
        )
        XCTAssertEqual(
            UsageFormatting.lastUpdated(date, now: now, localization: AppLocalization(language: .english)),
            "Updated 5 minutes ago"
        )
    }

    func testHeaderTitleUsesSingleLineProductWording() {
        XCTAssertEqual(
            AppLocalization(language: .simplifiedChinese).headerTitle,
            "Codex剩余用量"
        )
        XCTAssertEqual(
            AppLocalization(language: .english).headerTitle,
            "Codex Usage Remaining"
        )
    }

    func testWindowTitlesUseDurationInsteadOfPrimaryOrSecondaryPosition() {
        let chinese = AppLocalization(language: .simplifiedChinese)
        let english = AppLocalization(language: .english)

        XCTAssertEqual(chinese.windowTitle(durationMinutes: 300), "5 小时")
        XCTAssertEqual(chinese.windowTitle(durationMinutes: 10_080), "1 周")
        XCTAssertEqual(chinese.windowTitle(durationMinutes: 480), "8 小时")
        XCTAssertEqual(chinese.windowTitle(durationMinutes: 20_160), "14 天")
        XCTAssertEqual(chinese.windowTitle(durationMinutes: 90), "90 分钟")

        XCTAssertEqual(english.windowTitle(durationMinutes: 300), "5 hours")
        XCTAssertEqual(english.windowTitle(durationMinutes: 10_080), "1 week")
        XCTAssertEqual(english.windowTitle(durationMinutes: 480), "8 hours")
        XCTAssertEqual(english.windowTitle(durationMinutes: 20_160), "14 days")
        XCTAssertEqual(english.windowTitle(durationMinutes: 90), "90 min")
    }
}
