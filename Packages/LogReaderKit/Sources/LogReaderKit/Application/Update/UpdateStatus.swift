import Foundation

public struct UpdateStatus: Sendable, Equatable, Decodable {
    public let phase: UpdatePhase
    public let startedAt: Date
    public let commit: String?
    public let message: String?

    public init(phase: UpdatePhase, startedAt: Date, commit: String?, message: String?) {
        self.phase = phase
        self.startedAt = startedAt
        self.commit = commit
        self.message = message
    }
}
