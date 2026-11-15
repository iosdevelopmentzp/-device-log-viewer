import Foundation
import LogReaderCore

public enum ProfileLoadResult: Sendable, Equatable {
    case missing
    case loaded(LogProfile, modifiedAt: Date)
    case failed(String, modifiedAt: Date?)
}
