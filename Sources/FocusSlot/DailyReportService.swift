import FocusSlotCore
import Foundation

/// Generates a Slack/Geekbot-style daily standup update from task events,
/// using an OpenAI-compatible chat completions endpoint.
///
/// The endpoint is configurable (base URL + model), so the same code works with
/// OpenAI, OpenRouter, a local Ollama server, or any OpenAI-compatible API.
struct DailyReportService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(status: Int, body: String)
        case emptyResponse
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add an AI API key in settings to generate dailies."
            case .invalidURL:
                return "The AI base URL in settings is not a valid URL."
            case .requestFailed(let status, let body):
                return "AI request failed (\(status)): \(body)"
            case .emptyResponse:
                return "The AI returned an empty response."
            case .decodingFailed:
                return "Could not read the AI response."
            }
        }
    }

    private let defaultBaseURL = "https://api.openai.com/v1"
    private let defaultModel = "gpt-4o-mini"

    func generate(
        yesterday: [CalendarEvent],
        today: [CalendarEvent],
        yesterdayDate: Date,
        todayDate: Date,
        settings: SchedulingSettings
    ) async throws -> String {
        guard let apiKey = settings.aiApiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let baseURL = (settings.aiBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? defaultBaseURL
        let model = (settings.aiModel?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? defaultModel

        let trimmedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(trimmedBase)/chat/completions") else {
            throw ServiceError.invalidURL
        }

        let userPrompt = Self.userPrompt(
            yesterday: yesterday,
            today: today,
            yesterdayDate: yesterdayDate,
            todayDate: todayDate
        )

        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: Self.systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.4
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ServiceError.requestFailed(status: http.statusCode, body: String(bodyText.prefix(500)))
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw ServiceError.decodingFailed
        }

        guard let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw ServiceError.emptyResponse
        }

        return text
    }

    // MARK: - Prompt building

    private static let systemPrompt = """
    You write a software developer's daily standup update to paste into a Slack \
    Geekbot check-in. Output GitHub-flavored markdown only — no preamble, no \
    closing remarks, no headings other than the three section labels below.

    Produce exactly three sections, each a bold label followed by the content:
    *What I did since yesterday*
    *What I'll do today*
    *Anything blocking my progress*

    CRITICAL — use ONLY the tasks given to you. Never invent, assume, or pad with \
    tasks, progress, or blockers that are not in the input. Rephrasing the given \
    tasks is fine; adding anything new is not.

    Rules:
    - Write each section as a few short, natural sentences in the first person — NOT a \
      bullet list of every task. Summarize and group; don't enumerate one bullet per task.
    - Do NOT mention task categories or labels.
    - Add a nested "- " sub-bullet ONLY when a task description carries an extra detail \
      worth calling out; otherwise add no sub-bullets at all.
    - Mention finished work as done (a ✅ is fine); keep it tight, no fluff.
    - If a section's input says "(nothing logged)", write exactly "Nothing" for that \
      section — do not fabricate items to fill it.
    - For blockers, mention one only if a task description clearly states a blocker; \
      otherwise write "None".
    """

    private static func userPrompt(
        yesterday: [CalendarEvent],
        today: [CalendarEvent],
        yesterdayDate: Date,
        todayDate: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"

        var lines: [String] = []
        lines.append("Yesterday (\(formatter.string(from: yesterdayDate))):")
        lines.append(contentsOf: taskLines(yesterday, includeDoneMarker: true))
        lines.append("")
        lines.append("Today (\(formatter.string(from: todayDate))):")
        lines.append(contentsOf: taskLines(today, includeDoneMarker: true))
        return lines.joined(separator: "\n")
    }

    private static func taskLines(_ events: [CalendarEvent], includeDoneMarker: Bool) -> [String] {
        // Personal [Life] tasks are excluded from work standups.
        let workEvents = events.filter { TaskTitleFormatter.category(for: $0.title) != .life }
        guard !workEvents.isEmpty else { return ["(nothing logged)"] }

        return workEvents.map { event in
            let title = TaskTitleFormatter.displayTitle(for: event.title)
            let done = includeDoneMarker && TaskTitleFormatter.isDone(event.title)

            var line = "- \(title)"
            if done {
                line += " (done)"
            }
            if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                let oneLine = notes.replacingOccurrences(of: "\n", with: " ")
                line += " — \(oneLine)"
            }
            return line
        }
    }
}

// MARK: - OpenAI-compatible wire types

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Codable {
    let role: String
    let content: String?
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        let message: ChatMessage
    }
    let choices: [Choice]
}
