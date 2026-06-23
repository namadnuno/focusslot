import FocusSlotCore
import XCTest

final class SchedulingServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var service: SchedulingService!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        service = SchedulingService(calendar: calendar)
    }

    func testFutureDayUsesWorkdayStartWhenFree() {
        let day = date(year: 2026, month: 6, day: 24, hour: 0, minute: 0)
        let now = date(year: 2026, month: 6, day: 23, hour: 14, minute: 7)

        let slot = service.findBestSlot(
            selectedDate: day,
            durationMinutes: 30,
            now: now,
            fixedEvents: [],
            taskEvents: [],
            settings: SchedulingSettings()
        )

        XCTAssertEqual(slot?.start, date(year: 2026, month: 6, day: 24, hour: 9, minute: 0))
        XCTAssertEqual(slot?.end, date(year: 2026, month: 6, day: 24, hour: 9, minute: 30))
    }

    func testTodayRoundsNowAndAddsBuffer() {
        let now = date(year: 2026, month: 6, day: 23, hour: 14, minute: 7)

        let slot = service.findBestSlot(
            selectedDate: now,
            durationMinutes: 15,
            now: now,
            fixedEvents: [],
            taskEvents: [],
            settings: SchedulingSettings()
        )

        XCTAssertEqual(slot?.start, date(year: 2026, month: 6, day: 23, hour: 14, minute: 15))
        XCTAssertEqual(slot?.end, date(year: 2026, month: 6, day: 23, hour: 14, minute: 30))
    }

    func testBusyIntervalsWithBufferAreAvoided() {
        let day = date(year: 2026, month: 6, day: 24, hour: 0, minute: 0)
        let meeting = CalendarEvent(
            id: "meeting",
            title: "Standup",
            startDate: date(year: 2026, month: 6, day: 24, hour: 9, minute: 30),
            endDate: date(year: 2026, month: 6, day: 24, hour: 10, minute: 0)
        )

        let slot = service.findBestSlot(
            selectedDate: day,
            durationMinutes: 30,
            now: date(year: 2026, month: 6, day: 23, hour: 12, minute: 0),
            fixedEvents: [meeting],
            taskEvents: [],
            settings: SchedulingSettings()
        )

        XCTAssertEqual(slot?.start, date(year: 2026, month: 6, day: 24, hour: 10, minute: 5))
    }

    func testLunchWindowIsExcluded() {
        let day = date(year: 2026, month: 6, day: 24, hour: 0, minute: 0)
        let morningBlock = CalendarEvent(
            id: "morning",
            title: "Workshop",
            startDate: date(year: 2026, month: 6, day: 24, hour: 9, minute: 0),
            endDate: date(year: 2026, month: 6, day: 24, hour: 13, minute: 0)
        )

        let slot = service.findBestSlot(
            selectedDate: day,
            durationMinutes: 30,
            now: date(year: 2026, month: 6, day: 23, hour: 12, minute: 0),
            fixedEvents: [morningBlock],
            taskEvents: [],
            settings: SchedulingSettings(bufferMinutes: 0)
        )

        XCTAssertEqual(slot?.start, date(year: 2026, month: 6, day: 24, hour: 14, minute: 0))
    }

    func testPastDaysReturnNoSlot() {
        let slot = service.findBestSlot(
            selectedDate: date(year: 2026, month: 6, day: 22, hour: 0, minute: 0),
            durationMinutes: 30,
            now: date(year: 2026, month: 6, day: 23, hour: 12, minute: 0),
            fixedEvents: [],
            taskEvents: [],
            settings: SchedulingSettings()
        )

        XCTAssertNil(slot)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
