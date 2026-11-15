import Foundation
import LogReaderCore

public enum TextStyle: Sendable, Equatable {
    case message(LevelStyle?)
    case preview
    case detail
    case title
    case fieldKey
    case fieldValue
    case globalMatch
    case localMatch
    case badge
}
