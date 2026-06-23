import Foundation

public struct SchedulingSettings: Codable, Equatable, Sendable {
    public var workdayStartHour: Int
    public var workdayStartMinute: Int
    public var workdayEndHour: Int
    public var workdayEndMinute: Int
    public var lunchStartHour: Int
    public var lunchStartMinute: Int
    public var lunchEndHour: Int
    public var lunchEndMinute: Int
    public var bufferMinutes: Int
    public var slotGranularityMinutes: Int
    public var calendarIdentifier: String?
    public var autoRebalance: Bool

    public init(
        workdayStartHour: Int = 9,
        workdayStartMinute: Int = 0,
        workdayEndHour: Int = 18,
        workdayEndMinute: Int = 0,
        lunchStartHour: Int = 13,
        lunchStartMinute: Int = 0,
        lunchEndHour: Int = 14,
        lunchEndMinute: Int = 0,
        bufferMinutes: Int = 5,
        slotGranularityMinutes: Int = 5,
        calendarIdentifier: String? = nil,
        autoRebalance: Bool = false
    ) {
        self.workdayStartHour = workdayStartHour
        self.workdayStartMinute = workdayStartMinute
        self.workdayEndHour = workdayEndHour
        self.workdayEndMinute = workdayEndMinute
        self.lunchStartHour = lunchStartHour
        self.lunchStartMinute = lunchStartMinute
        self.lunchEndHour = lunchEndHour
        self.lunchEndMinute = lunchEndMinute
        self.bufferMinutes = bufferMinutes
        self.slotGranularityMinutes = slotGranularityMinutes
        self.calendarIdentifier = calendarIdentifier
        self.autoRebalance = autoRebalance
    }
}

public struct CalendarEvent: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarIdentifier: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendarIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarIdentifier = calendarIdentifier
    }
}

public struct TaskDraft: Equatable, Sendable {
    public let title: String
    public let durationMinutes: Int
    public let selectedDate: Date

    public init(title: String, durationMinutes: Int, selectedDate: Date) {
        self.title = title
        self.durationMinutes = durationMinutes
        self.selectedDate = selectedDate
    }
}

public struct TaskEvent: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let durationMinutes: Int

    public init(id: String, title: String, durationMinutes: Int) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
    }
}

public struct ScheduledTask: Equatable, Sendable {
    public let task: TaskEvent
    public let interval: DateInterval?

    public init(task: TaskEvent, interval: DateInterval?) {
        self.task = task
        self.interval = interval
    }
}
