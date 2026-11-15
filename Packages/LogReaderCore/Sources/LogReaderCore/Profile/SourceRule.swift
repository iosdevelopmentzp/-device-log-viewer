import Foundation

public struct SourceRule: Codable, Sendable, Equatable {

    public var fileExtension: String
    public var editorCommand: String
    public var editorArguments: [String]

    public static let standard = SourceRule(
        fileExtension: "swift",
        editorCommand: "/usr/bin/xed",
        editorArguments: ["--line", "{line}", "{path}"]
    )

    public static let linePlaceholder = "{line}"
    public static let pathPlaceholder = "{path}"

    public init(fileExtension: String, editorCommand: String, editorArguments: [String]) {
        self.fileExtension = fileExtension
        self.editorCommand = editorCommand
        self.editorArguments = editorArguments
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fileExtension = try container.decodeIfPresent(String.self, forKey: .fileExtension) ?? Self.standard.fileExtension
        self.editorCommand = try container.decodeIfPresent(String.self, forKey: .editorCommand) ?? Self.standard.editorCommand
        self.editorArguments = try container.decodeIfPresent([String].self, forKey: .editorArguments) ?? Self.standard.editorArguments
    }

    public func editorArguments(path: String, line: Int?) -> [String] {
        editorArguments.compactMap { argument in
            switch argument {
            case Self.pathPlaceholder: path
            case Self.linePlaceholder: line.map(String.init)
            default: argument
            }
        }
    }
}
