import Foundation
import LogReaderKit

final class FakeFileTrasher: FileTrasher {

    var errorToThrow: (any Error)?
    var failingURL: URL?
    private(set) var trashedURLs: [URL] = []

    func trash(_ url: URL) throws {
        if let errorToThrow, failingURL == nil || failingURL == url {
            throw errorToThrow
        }
        trashedURLs.append(url)
    }
}
