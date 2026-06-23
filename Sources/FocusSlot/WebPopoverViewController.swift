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
                        startDate: request.startDate
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
