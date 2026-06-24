import Foundation

public enum TaskCategory: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case cs = "CS"
    case bugs = "Bugs"
    case feature = "Feature"
    case pair = "Pair"
    case investigation = "Investigation"
    case life = "Life"

    public var id: String { rawValue }
}
