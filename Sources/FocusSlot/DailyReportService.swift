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

    /// The generated update plus token usage and a best-effort cost estimate.
    struct Report {
        let text: String
        let model: String
        let promptTokens: Int
        let completionTokens: Int
        /// Estimated USD cost; nil when the model's price is unknown.
        let costUSD: Double?
    }

    func generate(
        yesterday: [CalendarEvent],
        today: [CalendarEvent],
        yesterdayDate: Date,
        todayDate: Date,
        settings: SchedulingSettings
    ) async throws -> Report {
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

        let promptTokens = decoded.usage?.prompt_tokens ?? 0
        let completionTokens = decoded.usage?.completion_tokens ?? 0

        return Report(
            text: text,
            model: model,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            costUSD: Self.estimatedCost(model: model, promptTokens: promptTokens, completionTokens: completionTokens)
        )
    }

    // MARK: - Cost estimation

    /// Per-1M-token USD prices for common OpenAI models (input, output).
    /// Best-effort and may drift — surfaced as an estimate. Unknown models → nil cost.
    private static let prices: [(prefix: String, input: Double, output: Double)] = [
        ("gpt-4o-mini", 0.15, 0.60),
        ("gpt-4o", 2.50, 10.00),
        ("gpt-4.1-nano", 0.10, 0.40),
        ("gpt-4.1-mini", 0.40, 1.60),
        ("gpt-4.1", 2.00, 8.00)
    ]

    private static func estimatedCost(model: String, promptTokens: Int, completionTokens: Int) -> Double? {
        // Longest prefix wins (e.g. "gpt-4o-mini" before "gpt-4o").
        let match = prices
            .filter { model.hasPrefix($0.prefix) }
            .max { $0.prefix.count < $1.prefix.count }

        guard let match else { return nil }

        return Double(promptTokens) / 1_000_000 * match.input
            + Double(completionTokens) / 1_000_000 * match.output
    }

    // MARK: - Prompt building

    private static let systemPrompt = """
    You write a software developer's daily standup update to paste into a Slack \
    Geekbot check-in. Output GitHub-flavored markdown only — no preamble, no \
    closing remarks, no headings other than the three section labels below.

    Produce exactly three sections, each a bold label on its own line followed by \
    "- " bullet points:
    *What I did since yesterday*
    *What I'll do today*
    *Anything blocking my progress*

    CRITICAL — use ONLY the tasks given to you. Never invent, assume, or pad with \
    tasks, progress, or blockers that are not in the input. Rephrasing is fine; \
    adding new items is not.

    Formatting:
    - One "- " bullet per task, leading with a verb, e.g. "- Fixed the login flow".
    - Mark finished work with a ✅ at the end of its bullet.

    Descriptions (a line may include "| description: ...") — these carry the real \
    context, USE THEM:
    - Let the description shape the main bullet's wording. The title is often terse; \
      the description usually says what actually matters. Prefer a specific, \
      informative bullet drawn from the description over a vague restatement of the title.
    - For today's tasks, use the description to define what you'll actually work on.
    - For yesterday's tasks, use it to add the concrete detail of what you did.
    - Add a nested "- " sub-bullet when the description holds a distinct extra point \
      (a caveat, a follow-up, a finding) that doesn't fit cleanly in the main bullet; \
      otherwise fold it into the main bullet and add no sub-bullet.
    - Never print the literal text "| description:" — it is an input marker only.

    Categories (each input line is tagged with its category in [brackets] FOR YOUR \
    REFERENCE ONLY — never print the bracket or the category name):
    - For [CS] tasks, generalize: drop personal names and phrase as customer-support \
      work. Example: "Support Bradon on the billing bug" → "Support CS on billing \
      related issues".

    What to leave out:
    - Skip trivial throwaway tasks that aren't real work updates — e.g. \
      "tell/ask/ping/message someone something", quick chats, personal admin. Omit \
      them entirely rather than listing them.

    Empty sections:
    - If a section's input is "(nothing logged)", or every item in it was skipped, \
      write exactly "- Nothing".
    - For blockers, include one only if a description clearly states a blocker; \
      otherwise write "- None".
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
            let category = TaskTitleFormatter.category(for: event.title)?.rawValue
            let done = includeDoneMarker && TaskTitleFormatter.isDone(event.title)

            var line = "- "
            if let category {
                line += "[\(category)] "
            }
            line += title
            if done {
                line += " (done)"
            }
            if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                let oneLine = notes.replacingOccurrences(of: "\n", with: " ")
                line += " | description: \(oneLine)"
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
    struct Usage: Decodable {
        let prompt_tokens: Int?
        let completion_tokens: Int?
    }
    let choices: [Choice]
    let usage: Usage?
}
