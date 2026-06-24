import EventKit
import FocusSlotCore
import Foundation

struct WebCalendarOption: Encodable {
    let id: String
    let title: String
    let source: String
    let allowsContentModifications: Bool

    init(calendar: EKCalendar) {
        id = calendar.calendarIdentifier
        title = calendar.title
        source = calendar.source.title
        allowsContentModifications = calendar.allowsContentModifications
    }
}

struct WebCalendarTask: Encodable {
    let id: String
    let title: String
    let displayTitle: String
    let category: TaskCategory?
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let isDone: Bool
    let notes: String?

    init(event: CalendarEvent) {
        id = event.id
        title = event.title
        displayTitle = TaskTitleFormatter.displayTitle(for: event.title)
        category = TaskTitleFormatter.category(for: event.title)
        startDate = event.startDate
        endDate = event.endDate
        durationMinutes = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        isDone = TaskTitleFormatter.isDone(event.title)
        notes = event.notes
    }
}

struct WebAccessState: Encodable {
    let status: String
    let message: String?

    init(_ state: CalendarController.AccessState) {
        switch state {
        case .unknown:
            status = "unknown"
            message = nil
        case .requesting:
            status = "requesting"
            message = nil
        case .granted:
            status = "granted"
            message = nil
        case .denied(let reason):
            status = "denied"
            message = reason
        }
    }
}

struct WebAppState: Encodable {
    let accessState: WebAccessState
    let calendars: [WebCalendarOption]
    let settings: SchedulingSettings
    let tasks: [WebCalendarTask]
    let selectedDate: Date
    let isLoading: Bool

    init(
        accessState: CalendarController.AccessState,
        calendars: [EKCalendar],
        settings: SchedulingSettings,
        tasks: [CalendarEvent],
        selectedDate: Date,
        isLoading: Bool
    ) {
        self.accessState = WebAccessState(accessState)
        self.calendars = calendars
            .filter(\.allowsContentModifications)
            .map(WebCalendarOption.init)
        self.settings = settings
        self.tasks = tasks.map(WebCalendarTask.init)
        self.selectedDate = selectedDate
        self.isLoading = isLoading
    }
}

struct SelectedDatePayload: Decodable {
    let selectedDate: Date
}

struct AddTaskPayload: Decodable {
    let title: String
    let category: TaskCategory
    let durationMinutes: Int
    let selectedDate: Date
    /// Optional explicit start time; absent when the task should be auto-scheduled.
    let startDate: Date?
    let notes: String?
}

struct UpdateTaskPayload: Decodable {
    let eventID: String
    let title: String
    let category: TaskCategory
    let startDate: Date
    let durationMinutes: Int
    let selectedDate: Date
    let notes: String?
}

struct GenerateDailyResult: Encodable {
    let text: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let costUSD: Double?
}

struct OrganizeResult: Encodable {
    let state: WebAppState
    let summary: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let costUSD: Double?
    let movedCount: Int
}

struct EventActionPayload: Decodable {
    let eventID: String
    let selectedDate: Date
}

struct MoveTaskPayload: Decodable {
    let eventID: String
    let offsetMinutes: Int
    let nextDay: Bool
    let selectedDate: Date
}

struct UpdateSettingsPayload: Decodable {
    let settings: SchedulingSettings
    let selectedDate: Date
}
