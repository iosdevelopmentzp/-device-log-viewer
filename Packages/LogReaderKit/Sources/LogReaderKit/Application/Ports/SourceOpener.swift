import Foundation
import LogReaderCore

public protocol SourceOpener: AnyObject {
    func open(_ url: URL, line: Int?, editor: SourceRule) throws
}
