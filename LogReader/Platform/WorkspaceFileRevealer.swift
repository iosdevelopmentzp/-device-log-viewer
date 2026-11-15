import AppKit
import LogReaderKit

final class WorkspaceFileRevealer {
}

// MARK: - FileRevealer

extension WorkspaceFileRevealer: FileRevealer {

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
