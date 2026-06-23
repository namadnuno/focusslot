import Foundation

public enum TaskTitleFormatter {
    public static let taskPrefix = "[Task]"
    private static let doneToken = "\u{2705}"

    public static func isTaskTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix(taskPrefix) || trimmed.hasPrefix("\(doneToken) \(taskPrefix)")
    }

    public static func isDone(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("\(doneToken) \(taskPrefix)") || trimmed.hasPrefix("\(taskPrefix) \(doneToken)")
    }

    public static func eventTitle(for rawTitle: String) -> String {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(taskPrefix) \(title)"
    }

    public static func doneTitle(for title: String) -> String {
        let displayTitle = displayTitle(for: title)
        return "\(doneToken) \(taskPrefix) \(displayTitle)"
    }

    public static func displayTitle(for title: String) -> String {
        var value = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix(doneToken) {
            value.removeFirst(doneToken.count)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if value.hasPrefix(taskPrefix) {
            value.removeFirst(taskPrefix.count)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if value.hasPrefix(doneToken) {
            value.removeFirst(doneToken.count)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return value
    }
}
