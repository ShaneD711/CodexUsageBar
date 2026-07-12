import Foundation
import XCTest
@testable import CodexUsageBar

final class AppLocalizationTests: XCTestCase {
    func testChineseLanguageIdentifiersSelectSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-CN"]), .simplifiedChinese)
    }

    func testEnglishAndUnknownLanguagesUseEnglish() {
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
}
