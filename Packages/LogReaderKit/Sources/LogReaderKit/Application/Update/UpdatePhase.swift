import Foundation

public enum UpdatePhase: String, Sendable, Equatable, CaseIterable, Decodable {
    case fetching
    case building
    case installing
    case done
    case failed
}
