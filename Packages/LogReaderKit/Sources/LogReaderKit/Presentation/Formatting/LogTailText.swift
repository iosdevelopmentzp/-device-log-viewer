import Foundation

public enum LogTailText {

    public static func lastLines(of text: String, count: Int) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let trimmed = lines.last?.isEmpty == true ? lines.dropLast() : lines[...]
        return trimmed.suffix(count).joined(separator: "\n")
    }
}
