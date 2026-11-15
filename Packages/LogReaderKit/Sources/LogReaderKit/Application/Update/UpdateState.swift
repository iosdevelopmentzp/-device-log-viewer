import Foundation

public enum UpdateState: Sendable, Equatable {
    case idle
    case upToDate
    case available([UpdateCommit])
    case running(UpdatePhase, startedAt: Date)
    case failed(message: String)
    case updated(shortHash: String)

    public var isRunning: Bool {
        guard case .running = self else { return false }
        return true
    }
}
