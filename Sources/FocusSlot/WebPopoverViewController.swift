import AppKit
import FocusSlotCore
import WebKit

final class WebPopoverViewController: NSViewController, WKScriptMessageHandler {
    private let calendarController: CalendarController
    private let settingsStore: SettingsStore
    private var webView: WKWebView!
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(calendarController: CalendarController, settingsStore: SettingsStore) {
        self.calendarController = calendarController
        self.settingsStore = settingsStore
        super.init(nibName: nil, bundle: nil)

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "focusSlot")
        contentController.addUserScript(Self.loggingScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadFrontend()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "focusSlot",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }

        if type == "__log" {
            handleLogMessage(body)
            return
        }

        if type == "__frontendReady" {
            FocusSlotLogger.log("Frontend ready")
            return
        }

        guard let id = body["id"] as? String else {
            FocusSlotLogger.log("Ignoring native request without id: \(body)")
            return
        }

        Task { @MainActor in
            await handleRequest(id: id, type: type, payload: body["payload"])
        }
    }

    @MainActor
    private func handleRequest(id: String, type: String, payload: Any?) async {
        do {
            switch type {
            case "initialize":
                let request = try decode(SelectedDatePayload.self, from: payload)
                await calendarController.start(settings: settingsStore.settings, selectedDate: request.selectedDate)

                if settingsStore.settings.calendarIdentifier == nil,
                   let identifier = calendarController.defaultCalendarIdentifier() {
                    settingsStore.updateCalendarIdentifier(identifier)
                    await calendarController.loadEvents(for: request.selectedDate, settings: settingsStore.settings)
                }

                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "loadEvents":
                let request = try decode(SelectedDatePayload.self, from: payload)
                await calendarController.loadEvents(for: request.selectedDate, settings: settingsStore.settings)
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "addTask":
                let request = try decode(AddTaskPayload.self, from: payload)
                _ = try await calendarController.addTask(
                    TaskDraft(
                        title: request.title,
                        category: request.category,
                        durationMinutes: request.durationMinutes,
                        selectedDate: request.selectedDate,
                        startDate: request.startDate,
                        notes: request.notes
                    ),
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "updateTask":
                let request = try decode(UpdateTaskPayload.self, from: payload)
                try await calendarController.updateTask(
                    eventID: request.eventID,
                    title: request.title,
                    category: request.category,
                    startDate: request.startDate,
                    durationMinutes: request.durationMinutes,
                    notes: request.notes,
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "markDone":
                let request = try decode(EventActionPayload.self, from: payload)
                try await calendarController.markDone(
                    eventID: request.eventID,
                    selectedDate: request.selectedDate,
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "moveNext":
                let request = try decode(EventActionPayload.self, from: payload)
                _ = try await calendarController.moveToNextAvailableSlot(
                    eventID: request.eventID,
                    selectedDate: request.selectedDate,
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "moveTask":
                let request = try decode(MoveTaskPayload.self, from: payload)
                _ = try await calendarController.moveTask(
                    eventID: request.eventID,
                    offsetMinutes: request.offsetMinutes,
                    nextDay: request.nextDay,
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "deleteTask":
                let request = try decode(EventActionPayload.self, from: payload)
                try await calendarController.delete(
                    eventID: request.eventID,
                    selectedDate: request.selectedDate,
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "updateSettings":
                let request = try decode(UpdateSettingsPayload.self, from: payload)
                settingsStore.settings = request.settings
                await calendarController.loadEvents(for: request.selectedDate, settings: settingsStore.settings)
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "applyReminderToExisting":
                let request = try decode(SelectedDatePayload.self, from: payload)
                let count = try await calendarController.applyReminderToExistingTasks(
                    settings: settingsStore.settings
                )
                FocusSlotLogger.log("Applied reminder to \(count) existing tasks")
                await calendarController.loadEvents(for: request.selectedDate, settings: settingsStore.settings)
                try sendSuccess(id: id, result: appState(selectedDate: request.selectedDate))
            case "generateDaily":
                let request = try decode(SelectedDatePayload.self, from: payload)
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: request.selectedDate)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

                let yesterdayTasks = calendarController.fetchTaskEvents(on: yesterday, settings: settingsStore.settings)
                let todayTasks = calendarController.fetchTaskEvents(on: today, settings: settingsStore.settings)

                let report = try await DailyReportService().generate(
                    yesterday: yesterdayTasks,
                    today: todayTasks,
                    yesterdayDate: yesterday,
                    todayDate: today,
                    settings: settingsStore.settings
                )
                try sendSuccess(id: id, result: GenerateDailyResult(
                    text: report.text,
                    model: report.model,
                    promptTokens: report.promptTokens,
                    completionTokens: report.completionTokens,
                    costUSD: report.costUSD
                ))
            case "organizeSchedule":
                let request = try decode(SelectedDatePayload.self, from: payload)
                try await organizeSchedule(id: id, selectedDate: request.selectedDate)
            case "openCalendarSettings":
                openCalendarSettings()
                try sendSuccess(id: id, result: EmptyResult())
            default:
                FocusSlotLogger.log("Unknown native command: \(type)")
                sendFailure(id: id, error: "Unknown native command: \(type)")
            }
        } catch {
            FocusSlotLogger.log("Native command failed: \(type) - \(error.localizedDescription)")
            sendFailure(id: id, error: error.localizedDescription)
        }
    }

    @MainActor
    private func organizeSchedule(id: String, selectedDate: Date) async throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let isToday = calendar.isDateInToday(selectedDate)
        let now = Date()

        let (tasks, fixed) = calendarController.fetchEvents(on: selectedDate, settings: settingsStore.settings)

        // For today, only the not-yet-started tasks are movable; done and in-progress
        // tasks stay put. For future days, every (not-done) task is movable.
        let movable = tasks.filter {
            !TaskTitleFormatter.isDone($0.title) && (!isToday || $0.startDate > now)
        }

        guard !movable.isEmpty else {
            try sendSuccess(id: id, result: OrganizeResult(
                state: appState(selectedDate: selectedDate),
                summary: "No upcoming tasks to organize on this day.",
                model: "",
                promptTokens: 0,
                completionTokens: 0,
                costUSD: nil,
                movedCount: 0
            ))
            return
        }

        // Everything that must not be overlapped: real events plus the tasks we're not
        // moving (done / in-progress). All-day events would block the whole day, so skip them.
        let movableIDs = Set(movable.map(\.id))
        let anchoredTasks = tasks.filter { !movableIDs.contains($0.id) }
        let busyEvents = (fixed + anchoredTasks).filter { !$0.isAllDay }

        let result = try await DailyReportService().organize(
            movable: movable,
            busy: busyEvents,
            now: isToday ? now : nil,
            dayStart: dayStart,
            settings: settingsStore.settings
        )

        let durations = Dictionary(uniqueKeysWithValues: movable.map {
            ($0.id, $0.endDate.timeIntervalSince($0.startDate))
        })
        var busyIntervals = busyEvents.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        if isToday {
            busyIntervals.append(DateInterval(start: dayStart, end: now))
        }

        let accepted = Self.validateMoves(result.items, durations: durations, busy: busyIntervals)
        let movedCount = try await calendarController.applySchedule(
            accepted,
            selectedDate: selectedDate,
            settings: settingsStore.settings
        )

        let summary = Self.scheduleSummary(accepted: accepted, movable: movable)

        try sendSuccess(id: id, result: OrganizeResult(
            state: appState(selectedDate: selectedDate),
            summary: summary,
            model: result.model,
            promptTokens: result.promptTokens,
            completionTokens: result.completionTokens,
            costUSD: result.costUSD,
            movedCount: movedCount
        ))
    }

    /// Keeps only the proposed moves that don't clash with a busy interval or with an
    /// already-accepted move. Earlier start times win; the rest are dropped (left in place).
    private static func validateMoves(
        _ items: [(id: String, start: Date)],
        durations: [String: TimeInterval],
        busy: [DateInterval]
    ) -> [(id: String, start: Date)] {
        var accepted: [(id: String, start: Date)] = []
        var acceptedIntervals: [DateInterval] = []

        for item in items.sorted(by: { $0.start < $1.start }) {
            guard let duration = durations[item.id] else { continue }
            let interval = DateInterval(start: item.start, end: item.start.addingTimeInterval(duration))

            let clashesBusy = busy.contains { $0.intersects(interval) }
            let clashesAccepted = acceptedIntervals.contains { $0.intersects(interval) }
            if clashesBusy || clashesAccepted { continue }

            accepted.append(item)
            acceptedIntervals.append(interval)
        }

        return accepted
    }

    private static func scheduleSummary(
        accepted: [(id: String, start: Date)],
        movable: [CalendarEvent]
    ) -> String {
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"

        func title(for id: String) -> String {
            movable.first { $0.id == id }
                .map { TaskTitleFormatter.displayTitle(for: $0.title) } ?? "Task"
        }

        let acceptedIDs = Set(accepted.map(\.id))
        let movedLines = accepted
            .sorted { $0.start < $1.start }
            .map { "- \(clock.string(from: $0.start))  \(title(for: $0.id))" }

        let untouched = movable
            .filter { !acceptedIDs.contains($0.id) }
            .map { "- \(TaskTitleFormatter.displayTitle(for: $0.title))" }

        var lines: [String] = []
        if movedLines.isEmpty {
            lines.append("No tasks could be placed without clashing with your calendar.")
        } else {
            lines.append("Organized schedule:")
            lines.append(contentsOf: movedLines)
        }
        if !untouched.isEmpty {
            lines.append("")
            lines.append("Left in place (no clash-free slot found):")
            lines.append(contentsOf: untouched)
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    private func appState(selectedDate: Date) -> WebAppState {
        WebAppState(
            accessState: calendarController.accessState,
            calendars: calendarController.calendars,
            settings: settingsStore.settings,
            tasks: calendarController.taskEvents,
            selectedDate: selectedDate,
            isLoading: calendarController.isLoading
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from payload: Any?) throws -> T {
        guard let payload else {
            throw BridgeError.missingPayload
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        return try decoder.decode(T.self, from: data)
    }

    private func sendSuccess<T: Encodable>(id: String, result: T) throws {
        let response = NativeResponse(id: id, ok: true, result: result, error: nil)
        try send(response)
    }

    private func sendFailure(id: String, error: String) {
        let response = NativeResponse(id: id, ok: false, result: EmptyResult(), error: error)
        try? send(response)
    }

    private func send<T: Encodable>(_ response: NativeResponse<T>) throws {
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        webView.evaluateJavaScript("window.FocusSlotNative?.receive(\(json));")
    }

    private func loadFrontend() {
        guard let url = frontendURL() else {
            FocusSlotLogger.log("Frontend build not found")
            let html = "<html><body><p style=\"font: 13px -apple-system; padding: 20px;\">FocusSlot frontend was not built.</p></body></html>"
            webView.loadHTMLString(html, baseURL: nil)
            return
        }

        FocusSlotLogger.log("Loading frontend: \(url.path)")
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func frontendURL() -> URL? {
        if let bundledURL = Bundle.main.resourceURL?
            .appendingPathComponent("frontend")
            .appendingPathComponent("index.html"),
           FileManager.default.fileExists(atPath: bundledURL.path) {
            return bundledURL
        }

        let workingDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let localURL = workingDirectoryURL
            .appendingPathComponent("frontend")
            .appendingPathComponent("dist")
            .appendingPathComponent("index.html")

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        return nil
    }

    private func openCalendarSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func handleLogMessage(_ body: [String: Any]) {
        let level = body["level"] as? String ?? "log"
        let message = body["message"] as? String ?? ""
        let source = body["source"] as? String ?? "web"
        let line = body["line"] as? Int
        let column = body["column"] as? Int
        let location = [line, column].compactMap { $0 }.map(String.init).joined(separator: ":")
        let suffix = location.isEmpty ? "" : " @ \(location)"

        FocusSlotLogger.log("[\(source)] \(level): \(message)\(suffix)")
    }

    private static let loggingScript = WKUserScript(
        source: """
        (function () {
          function serialize(value) {
            try {
              if (value instanceof Error) {
                return JSON.stringify({
                  name: value.name,
                  message: value.message,
                  stack: value.stack
                });
              }
              if (typeof value === "object") {
                return JSON.stringify(value);
              }
              return String(value);
            } catch (_) {
              return String(value);
            }
          }

          function post(level, args, source, line, column) {
            try {
              window.webkit?.messageHandlers?.focusSlot?.postMessage({
                type: "__log",
                level: level,
                source: source || "console",
                line: line || null,
                column: column || null,
                message: Array.prototype.slice.call(args).map(serialize).join(" ")
              });
            } catch (_) {}
          }

          ["log", "info", "warn", "error", "debug"].forEach(function (level) {
            var original = console[level];
            console[level] = function () {
              post(level, arguments, "console");
              if (original) {
                original.apply(console, arguments);
              }
            };
          });

          window.addEventListener("error", function (event) {
            post("error", [event.message, event.error], event.filename || "window.error", event.lineno, event.colno);
          });

          window.addEventListener("unhandledrejection", function (event) {
            post("error", ["Unhandled promise rejection", event.reason], "unhandledrejection");
          });
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )
}

extension WebPopoverViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        FocusSlotLogger.log("WebView navigation finished")
        logWebViewDiagnostics(label: "after navigation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak webView] in
            guard let self, webView != nil else { return }
            self.logWebViewDiagnostics(label: "after 1s")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self, weak webView] in
            guard let self, webView != nil else { return }
            self.logWebViewDiagnostics(label: "after 3s")
        }
    }

    private func logWebViewDiagnostics(label: String) {
        webView.evaluateJavaScript(
            """
            (function () {
              var root = document.getElementById('root');
              return {
                title: document.title,
                rootChildren: root ? root.children.length : -1,
                rootText: root ? root.innerText.slice(0, 120) : 'missing-root',
                scripts: Array.prototype.map.call(document.scripts, function (script) {
                  return { src: script.src, type: script.type };
                })
              };
            })();
            """
        ) { result, error in
            if let error {
                FocusSlotLogger.log("WebView diagnostics \(label) failed: \(error.localizedDescription)")
            } else {
                FocusSlotLogger.log("WebView diagnostics \(label): \(String(describing: result))")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        FocusSlotLogger.log("WebView navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        FocusSlotLogger.log("WebView provisional navigation failed: \(error.localizedDescription)")
    }
}

private struct NativeResponse<T: Encodable>: Encodable {
    let id: String
    let ok: Bool
    let result: T?
    let error: String?
}

private struct EmptyResult: Encodable {}

private enum BridgeError: LocalizedError {
    case missingPayload

    var errorDescription: String? {
        switch self {
        case .missingPayload:
            return "Missing native command payload."
        }
    }
}
