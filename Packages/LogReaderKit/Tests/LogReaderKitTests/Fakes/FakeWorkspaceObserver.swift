import LogReaderKit

@MainActor
final class FakeWorkspaceObserver: WorkspaceObserver {

    private(set) var sessions: [LogSession] = []

    func workspace(_ workspace: Workspace, didChangeSession session: LogSession) {
        sessions.append(session)
    }
}
