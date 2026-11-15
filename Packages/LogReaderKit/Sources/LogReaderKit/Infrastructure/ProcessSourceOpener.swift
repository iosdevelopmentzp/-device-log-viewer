import Foundation
import LogReaderCore

public final class ProcessSourceOpener {

    public init() {}
}

// MARK: - SourceOpener

extension ProcessSourceOpener: SourceOpener {

    public func open(_ url: URL, line: Int?, editor: SourceRule) throws {
        guard FileManager.default.isExecutableFile(atPath: editor.editorCommand) else {
            throw EditorNotFoundError(command: editor.editorCommand)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: editor.editorCommand)
        process.arguments = editor.editorArguments(path: url.path, line: line)
        try process.run()
    }
}
