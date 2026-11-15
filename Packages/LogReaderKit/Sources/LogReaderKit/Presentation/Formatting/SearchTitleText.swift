import Foundation

enum SearchTitleText {

    private static let limit = 40

    static func shortened(_ text: String) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}
