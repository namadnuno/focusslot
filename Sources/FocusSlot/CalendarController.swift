import EventKit
import FocusSlotCore
import Foundation

@MainActor
final class CalendarController: ObservableObject {
    enum AccessState: Equatable {
        case unknown
        case requesting
        case granted
        case denied(String)
    }

    enum CalendarError: LocalizedError {
        case missingCalendar
        case eventNotFound
        case noSlot
        case pastDate
        case emptyTitle

        var errorDescription: String? {
            switch self {
            case .missingCalendar:
                return "Choose a writable calendar in settings."
            case .eventNotFound:
                return "This calendar event could not be found."
            case .noSlot:
                return "No available slot for this duration on the selected day."
            case .pastDate:
                return "Cannot schedule tasks in the past. Choose today or a future day."
            case .emptyTitle:
                return "Add a task title first."
            }
        }
    }

    @Published private(set) var accessState: AccessState = .unknown
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var taskEvents: [CalendarEvent] = []
    @Published private(set) var fixedEvents: [CalendarEvent] = []
    @Published private(set) var isLoading = false

    private let eventStore = EKEventStore()
    private let schedulingService = SchedulingService()

    var writableCalendars: [EKCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    func start(settings: SchedulingSettings, selectedDate: Date) async {
        await requestAccessIfNeeded()

        guard accessState == .granted else { return }

        loadCalendars()
        await loadEvents(for: selectedDate, settings: settings)
    }

    func defaultCalendarIdentifier() -> String? {
        eventStore.defaultCalendarForNewEvents?.calendarIdentifier ?? writableCalendars.first?.calendarIdentifier
    }

    func loadEvents(for selectedDate: Date, settings: SchedulingSettings) async {
        guard accessState == .granted else { return }

        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate).map(Self.calendarEvent)
        let taskCalendarID = selectedCalendar(settings: settings)?.calendarIdentifier

        taskEvents = events
            .filter {
                TaskTitleFormatter.isTaskTitle($0.title) &&
                    (taskCalendarID == nil || $0.calendarIdentifier == taskCalendarID)
            }
            .sorted { $0.startDate < $1.startDate }

        fixedEvents = events
            .filter {
                !TaskTitleFormatter.isTaskTitle($0.title) ||
                    (taskCalendarID != nil && $0.calendarIdentifier != taskCalendarID)
            }
            .sorted { $0.startDate < $1.startDate }
    }

    func addTask(_ draft: TaskDraft, settings: SchedulingSettings) async throws -> DateInterval {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CalendarError.emptyTitle }

        let calendar = Calendar.current
        guard calendar.startOfDay(for: draft.selectedDate) >= calendar.startOfDay(for: Date()) else {
            throw CalendarError.pastDate
        }

        await loadEvents(for: draft.selectedDate, settings: settings)

        let slot: DateInterval
        if let start = draft.startDate {
            // Honor the user-chosen start time instead of auto-scheduling.
            slot = DateInterval(start: start, duration: TimeInterval(draft.durationMinutes * 60))
        } else if let bestSlot = schedulingService.findBestSlot(
            selectedDate: draft.selectedDate,
            durationMinutes: draft.durationMinutes,
            now: Date(),
            fixedEvents: fixedEvents,
            taskEvents: taskEvents,
            settings: settings
        ) {
            slot = bestSlot
        } else {
            throw CalendarError.noSlot
        }

        guard let targetCalendar = selectedCalendar(settings: settings) else {
            throw CalendarError.missingCalendar
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = targetCalendar
        event.title = TaskTitleFormatter.eventTitle(for: title, category: draft.category)
        event.startDate = slot.start
        event.endDate = slot.end
        event.notes = normalizedNotes(draft.notes)
        applyReminder(to: event, settings: settings)

        try eventStore.save(event, span: .thisEvent, commit: true)
        await loadEvents(for: draft.selectedDate, settings: settings)
        return slot
    }

    func updateTask(
        eventID: String,
        title: String,
        category: TaskCategory?,
        startDate: Date,
        durationMinutes: Int,
        notes: String?,
        settings: SchedulingSettings
    ) async throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw CalendarError.emptyTitle }
        guard durationMinutes > 0 else { throw CalendarError.noSlot }
        guard let event = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }

        event.title = TaskTitleFormatter.eventTitle(for: cleanTitle, category: category)
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.notes = normalizedNotes(notes)
        applyReminder(to: event, settings: settings)

        try eventStore.save(event, span: .thisEvent, commit: true)
        await loadEvents(for: startDate, settings: settings)
    }

    /// Replaces the event's alarms to match the configured reminder setting.
    private func applyReminder(to event: EKEvent, settings: SchedulingSettings) {
        event.alarms = nil
        if let minutes = settings.reminderMinutes {
            event.alarms = [EKAlarm(relativeOffset: TimeInterval(-minutes * 60))]
        }
    }

    /// Applies the current reminder setting to existing upcoming task events
    /// (from the start of today forward). Returns the number of tasks updated.
    @discardableResult
    func applyReminderToExistingTasks(settings: SchedulingSettings) async throws -> Int {
        guard accessState == .granted else { throw CalendarError.missingCalendar }
        guard let targetCalendar = selectedCalendar(settings: settings) else {
            throw CalendarError.missingCalendar
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 365, to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [targetCalendar])

        var updated = 0
        for event in eventStore.events(matching: predicate) where TaskTitleFormatter.isTaskTitle(event.title) {
            applyReminder(to: event, settings: settings)
            try eventStore.save(event, span: .thisEvent, commit: false)
            updated += 1
        }
        try eventStore.commit()
        return updated
    }

    func markDone(eventID: String, selectedDate: Date, settings: SchedulingSettings) async throws {
        guard let event = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }

        event.title = TaskTitleFormatter.doneTitle(for: event.title)
        try eventStore.save(event, span: .thisEvent, commit: true)
        await loadEvents(for: selectedDate, settings: settings)
    }

    func moveToNextAvailableSlot(eventID: String, selectedDate: Date, settings: SchedulingSettings) async throws -> DateInterval {
        guard let event = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }

        await loadEvents(for: selectedDate, settings: settings)

        let movableEvent = Self.calendarEvent(event)
        let otherTasks = taskEvents.filter { $0.id != movableEvent.id }

        guard let slot = schedulingService.findBestSlot(
            selectedDate: selectedDate,
            durationMinutes: Int(movableEvent.endDate.timeIntervalSince(movableEvent.startDate) / 60),
            now: Date(),
            fixedEvents: fixedEvents,
            taskEvents: otherTasks,
            settings: settings
        ) else {
            throw CalendarError.noSlot
        }

        event.startDate = slot.start
        event.endDate = slot.end
        try eventStore.save(event, span: .thisEvent, commit: true)
        await loadEvents(for: selectedDate, settings: settings)
        return slot
    }

    /// Shifts a task by a fixed offset (or to the next day, preserving time of day).
    /// Returns the day the task now starts on, so the UI can follow it.
    @discardableResult
    func moveTask(
        eventID: String,
        offsetMinutes: Int,
        nextDay: Bool,
        settings: SchedulingSettings
    ) async throws -> Date {
        guard let event = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }

        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newStart: Date
        if nextDay {
            newStart = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate)
                ?? event.startDate.addingTimeInterval(86_400)
        } else {
            newStart = event.startDate.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        }

        event.startDate = newStart
        event.endDate = newStart.addingTimeInterval(duration)
        // Relative alarms move with the event automatically.
        try eventStore.save(event, span: .thisEvent, commit: true)
        await loadEvents(for: newStart, settings: settings)
        return newStart
    }

    func delete(eventID: String, selectedDate: Date, settings: SchedulingSettings) async throws {
        guard let event = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }

        try eventStore.remove(event, span: .thisEvent, commit: true)
        await loadEvents(for: selectedDate, settings: settings)
    }

    private func requestAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .event)

        if isGranted(status) {
            accessState = .granted
            return
        }

        if status == .denied || status == .restricted {
            accessState = .denied("Calendar access is needed to read busy time and create task blocks.")
            return
        }

        accessState = .requesting

        do {
            let granted: Bool

            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }

            accessState = granted ? .granted : .denied("Calendar access was denied.")
        } catch {
            accessState = .denied(error.localizedDescription)
        }
    }

    private func isGranted(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess || status == .authorized
        }

        return status == .authorized
    }

    private func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
            .sorted { lhs, rhs in
                if lhs.source.title == rhs.source.title {
                    return lhs.title < rhs.title
                }

                return lhs.source.title < rhs.source.title
            }
    }

    private func selectedCalendar(settings: SchedulingSettings) -> EKCalendar? {
        if let identifier = settings.calendarIdentifier,
           let calendar = calendars.first(where: { $0.calendarIdentifier == identifier }),
           calendar.allowsContentModifications {
            return calendar
        }

        if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
           defaultCalendar.allowsContentModifications {
            return defaultCalendar
        }

        return writableCalendars.first
    }

    /// Reads task events for a single day without mutating published state.
    /// Used by the daily generator, which inspects other days (yesterday/today)
    /// without disturbing the day the user is currently viewing.
    func fetchTaskEvents(on date: Date, settings: SchedulingSettings) -> [CalendarEvent] {
        fetchEvents(on: date, settings: settings).tasks
    }

    /// Non-mutating fetch of a day split into task events (managed by FocusSlot)
    /// and fixed/busy events (everything else, plus tasks on other calendars).
    func fetchEvents(on date: Date, settings: SchedulingSettings) -> (tasks: [CalendarEvent], fixed: [CalendarEvent]) {
        guard accessState == .granted else { return ([], []) }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate).map(Self.calendarEvent)
        let taskCalendarID = selectedCalendar(settings: settings)?.calendarIdentifier

        let tasks = events
            .filter {
                TaskTitleFormatter.isTaskTitle($0.title) &&
                    (taskCalendarID == nil || $0.calendarIdentifier == taskCalendarID)
            }
            .sorted { $0.startDate < $1.startDate }

        let fixed = events
            .filter {
                !TaskTitleFormatter.isTaskTitle($0.title) ||
                    (taskCalendarID != nil && $0.calendarIdentifier != taskCalendarID)
            }
            .sorted { $0.startDate < $1.startDate }

        return (tasks, fixed)
    }

    /// Moves the given task events to new start times, preserving each task's duration.
    /// Returns the number of events actually moved, then reloads the selected day.
    @discardableResult
    func applySchedule(
        _ moves: [(id: String, start: Date)],
        selectedDate: Date,
        settings: SchedulingSettings
    ) async throws -> Int {
        var moved = 0
        for move in moves {
            guard let event = eventStore.event(withIdentifier: move.id) else { continue }
            let duration = event.endDate.timeIntervalSince(event.startDate)
            event.startDate = move.start
            event.endDate = move.start.addingTimeInterval(duration)
            // Relative alarms move with the event automatically.
            try eventStore.save(event, span: .thisEvent, commit: false)
            moved += 1
        }

        if moved > 0 {
            try eventStore.commit()
        }

        await loadEvents(for: selectedDate, settings: settings)
        return moved
    }

    /// Trims notes and collapses empty strings to nil so EventKit clears the field.
    private func normalizedNotes(_ notes: String?) -> String? {
        guard let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func calendarEvent(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarIdentifier: event.calendar?.calendarIdentifier,
            notes: event.notes
        )
    }
}
