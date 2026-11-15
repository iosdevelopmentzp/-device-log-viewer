import Foundation

@MainActor
public protocol WorkspaceObserver: AnyObject {
    func workspace(_ workspace: Workspace, didChangeSession session: LogSession)
}
