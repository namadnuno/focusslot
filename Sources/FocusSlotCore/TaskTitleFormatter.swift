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

    public static func eventTitle(for rawTitle: String, category: TaskCategory? = nil) -> String {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            return "\(taskPrefix) [\(category.rawValue)] \(title)"
        }

        return "\(taskPrefix) \(title)"
    }

    public static func doneTitle(for title: String) -> String {
        let displayTitle = displayTitle(for: title)
        return "\(doneToken) \(eventTitle(for: displayTitle, category: category(for: title)))"
    }

    public static func category(for title: String) -> TaskCategory? {
        let value = valueAfterTaskPrefix(in: title)

        for category in TaskCategory.allCases {
            if value.hasPrefix("[\(category.rawValue)]") {
                return category
            }
        }

        return nil
    }

    public static func displayTitle(for title: String) -> String {
        var value = valueAfterTaskPrefix(in: title)

        if let category = category(for: title), value.hasPrefix("[\(category.rawValue)]") {
            value.removeFirst(category.rawValue.count + 2)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return value
    }

    private static func valueAfterTaskPrefix(in title: String) -> String {
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
