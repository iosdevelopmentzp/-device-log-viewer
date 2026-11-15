import Foundation
import LogReaderKit

final class FakeFileCopier: FileCopier {

    struct Copy: Equatable {
        let source: URL
        let destination: URL
        let replacing: Bool
    }

    var errorToThrow: (any Error)?
    private(set) var copies: [Copy] = []

    func copy(_ url: URL, to destination: URL, replacing: Bool) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        copies.append(Copy(source: url, destination: destination, replacing: replacing))
    }
}
