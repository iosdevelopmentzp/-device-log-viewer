import Foundation
import LogReaderCore
import LogReaderKit

final class FakeSourceOpener: SourceOpener {

    var errorToThrow: (any Error)?
    private(set) var opened: [(URL, Int?)] = []
    private(set) var editors: [SourceRule] = []

    func open(_ url: URL, line: Int?, editor: SourceRule) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        opened.append((url, line))
        editors.append(editor)
    }
}
