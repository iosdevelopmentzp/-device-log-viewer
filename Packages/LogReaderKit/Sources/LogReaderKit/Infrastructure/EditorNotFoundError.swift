import Foundation

public struct EditorNotFoundError: LocalizedError {

    public let command: String

    public var errorDescription: String? {
        "The editor command \(command) was not found. Check “source.editorCommand” in the profile."
    }
}
