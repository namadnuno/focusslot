import Foundation

public struct SchedulingService: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func findBestSlot(
        selectedDate: Date,
        durationMinutes: Int,
        now: Date,
        fixedEvents: [CalendarEvent],
        taskEvents: [CalendarEvent],
        settings: SchedulingSettings
    ) -> DateInterval? {
        guard durationMinutes > 0 else { return nil }

        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: now)
        guard selectedDay >= today else { return nil }

        let duration = TimeInterval(durationMinutes * 60)
        var windows = workingWindows(for: selectedDay, settings: settings)

        if selectedDay == today {
            let earliest = roundedUp(now, granularityMinutes: settings.slotGranularityMinutes)
                .addingTimeInterval(TimeInterval(settings.bufferMinutes * 60))
            windows = windows.compactMap { clip($0, earliestStart: earliest) }
        }

        let busyIntervals = busyIntervals(
            fixedEvents: fixedEvents,
            taskEvents: taskEvents,
            bufferMinutes: settings.bufferMinutes
        )

        let freeIntervals = subtract(busyIntervals, from: windows)
        let candidates = candidateSlots(
            in: freeIntervals,
            duration: duration,
            granularityMinutes: settings.slotGranularityMinutes
        )

        return candidates.min { lhs, rhs in
            score(lhs, selectedDay: selectedDay, durationMinutes: durationMinutes) <
                score(rhs, selectedDay: selectedDay, durationMinutes: durationMinutes)
        }?.interval
    }

    public func rebalanceTasksForDay(
        selectedDate: Date,
        now: Date,
        fixedEvents: [CalendarEvent],
        flexibleTasks: [TaskEvent],
        settings: SchedulingSettings
    ) -> [ScheduledTask] {
        var scheduled: [ScheduledTask] = []
        var taskEvents: [CalendarEvent] = []

        for task in flexibleTasks {
            let interval = findBestSlot(
                selectedDate: selectedDate,
                durationMinutes: task.durationMinutes,
                now: now,
                fixedEvents: fixedEvents,
                taskEvents: taskEvents,
                settings: settings
            )

            scheduled.append(ScheduledTask(task: task, interval: interval))

            if let interval {
                taskEvents.append(
                    CalendarEvent(
                        id: task.id,
                        title: task.title,
                        startDate: interval.start,
                        endDate: interval.end
                    )
                )
            }
        }

        return scheduled
    }

    private func workingWindows(for day: Date, settings: SchedulingSettings) -> [DateInterval] {
        let workdayStart = date(on: day, hour: settings.workdayStartHour, minute: settings.workdayStartMinute)
        let workdayEnd = date(on: day, hour: settings.workdayEndHour, minute: settings.workdayEndMinute)
        let lunchStart = date(on: day, hour: settings.lunchStartHour, minute: settings.lunchStartMinute)
        let lunchEnd = date(on: day, hour: settings.lunchEndHour, minute: settings.lunchEndMinute)

        guard workdayStart < workdayEnd else { return [] }

        if lunchStart < lunchEnd, lunchStart < workdayEnd, lunchEnd > workdayStart {
            return [
                DateInterval(start: workdayStart, end: Swift.min(lunchStart, workdayEnd)),
                DateInterval(start: Swift.max(lunchEnd, workdayStart), end: workdayEnd)
            ].filter { $0.duration > 0 }
        }

        return [DateInterval(start: workdayStart, end: workdayEnd)]
    }

    private func busyIntervals(
        fixedEvents: [CalendarEvent],
        taskEvents: [CalendarEvent],
        bufferMinutes: Int
    ) -> [DateInterval] {
        let buffer = TimeInterval(bufferMinutes * 60)

        return (fixedEvents + taskEvents)
            .filter { !$0.isAllDay && $0.startDate < $0.endDate }
            .map {
                DateInterval(
                    start: $0.startDate.addingTimeInterval(-buffer),
                    end: $0.endDate.addingTimeInterval(buffer)
                )
            }
            .sorted { $0.start < $1.start }
            .merged()
    }

    private func subtract(_ busyIntervals: [DateInterval], from windows: [DateInterval]) -> [DateInterval] {
        var freeIntervals: [DateInterval] = []

        for window in windows {
            var cursor = window.start

            for busy in busyIntervals where busy.end > window.start && busy.start < window.end {
                let busyStart = Swift.max(busy.start, window.start)
                let busyEnd = Swift.min(busy.end, window.end)

                if cursor < busyStart {
                    freeIntervals.append(DateInterval(start: cursor, end: busyStart))
                }

                cursor = Swift.max(cursor, busyEnd)
            }

            if cursor < window.end {
                freeIntervals.append(DateInterval(start: cursor, end: window.end))
            }
        }

        return freeIntervals.filter { $0.duration > 0 }
    }

    private func candidateSlots(
        in freeIntervals: [DateInterval],
        duration: TimeInterval,
        granularityMinutes: Int
    ) -> [CandidateSlot] {
        let step = TimeInterval(max(granularityMinutes, 1) * 60)
        var candidates: [CandidateSlot] = []

        for freeInterval in freeIntervals where freeInterval.duration >= duration {
            let latestStart = freeInterval.end.addingTimeInterval(-duration)
            var starts = Set<Date>([freeInterval.start, latestStart])
            var start = roundedUp(freeInterval.start, granularityMinutes: granularityMinutes)

            while start <= latestStart {
                starts.insert(start)
                start = start.addingTimeInterval(step)
            }

            for start in starts {
                let interval = DateInterval(start: start, duration: duration)
                if interval.start >= freeInterval.start, interval.end <= freeInterval.end {
                    candidates.append(CandidateSlot(interval: interval, freeInterval: freeInterval))
                }
            }
        }

        return candidates
    }

    private func score(_ candidate: CandidateSlot, selectedDay: Date, durationMinutes: Int) -> Double {
        let minutesFromStartOfDay = candidate.interval.start.timeIntervalSince(selectedDay) / 60
        let beforeGap = candidate.interval.start.timeIntervalSince(candidate.freeInterval.start) / 60
        let afterGap = candidate.freeInterval.end.timeIntervalSince(candidate.interval.end) / 60
        let totalLeftover = beforeGap + afterGap

        var score = minutesFromStartOfDay * 0.01
        score += min(totalLeftover, 60) * 0.02

        if beforeGap > 0, beforeGap < 10 {
            score += 50
        }

        if afterGap > 0, afterGap < 10 {
            score += 50
        }

        if durationMinutes >= 45, calendar.component(.hour, from: candidate.interval.start) < 12 {
            score -= 5
        }

        return score
    }

    private func clip(_ interval: DateInterval, earliestStart: Date) -> DateInterval? {
        let start = Swift.max(interval.start, earliestStart)
        guard start < interval.end else { return nil }
        return DateInterval(start: start, end: interval.end)
    }

    private func date(on day: Date, hour: Int, minute: Int) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) ?? day
    }

    private func roundedUp(_ date: Date, granularityMinutes: Int) -> Date {
        let granularity = TimeInterval(max(granularityMinutes, 1) * 60)
        let timestamp = date.timeIntervalSinceReferenceDate
        let roundedTimestamp = (timestamp / granularity).rounded(.up) * granularity
        return Date(timeIntervalSinceReferenceDate: roundedTimestamp)
    }
}

private struct CandidateSlot {
    let interval: DateInterval
    let freeInterval: DateInterval
}

private extension Array where Element == DateInterval {
    func merged() -> [DateInterval] {
        guard var current = first else { return [] }
        var intervals: [DateInterval] = []

        for interval in dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: Swift.max(current.end, interval.end))
            } else {
                intervals.append(current)
                current = interval
            }
        }

        intervals.append(current)
        return intervals
    }
}
