import Foundation

public struct ProjectItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let pathText: String
    public let statusText: String
    public let hasError: Bool
    public let canCreateExample: Bool

    public init(id: String, name: String, pathText: String, statusText: String, hasError: Bool, canCreateExample: Bool) {
        self.id = id
        self.name = name
        self.pathText = pathText
        self.statusText = statusText
        self.hasError = hasError
        self.canCreateExample = canCreateExample
    }
}
