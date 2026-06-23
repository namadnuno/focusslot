import FocusSlotCore
import XCTest

final class TaskTitleFormatterTests: XCTestCase {
    func testTaskTitleDetectionAndDisplayTitle() {
        XCTAssertTrue(TaskTitleFormatter.isTaskTitle("[Task] Investigate bug"))
        XCTAssertTrue(TaskTitleFormatter.isTaskTitle("\u{2705} [Task] Investigate bug"))
        XCTAssertEqual(TaskTitleFormatter.displayTitle(for: "[Task] Investigate bug"), "Investigate bug")
        XCTAssertEqual(TaskTitleFormatter.displayTitle(for: "\u{2705} [Task] Investigate bug"), "Investigate bug")
    }

    func testDoneTitleUsesTaskPrefix() {
        XCTAssertEqual(
            TaskTitleFormatter.doneTitle(for: "[Task] Investigate bug"),
            "\u{2705} [Task] Investigate bug"
        )
    }
}
