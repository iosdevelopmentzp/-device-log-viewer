import Foundation

public struct SourceReference: Sendable, Equatable {
    public let fileName: String
    public let line: Int?

    public init(fileName: String, line: Int?) {
        self.fileName = fileName
        self.line = line
    }

    public static func parse(_ source: String) -> SourceReference? {
        guard let colon = source.lastIndex(of: ":"), let line = Int(source[source.index(after: colon)...]) else {
            return source.isEmpty ? nil : SourceReference(fileName: source, line: nil)
        }
        let fileName = String(source[..<colon])
        guard fileName.isEmpty == false else { return nil }
        return SourceReference(fileName: fileName, line: line)
    }
}
