import Foundation
import LogReaderKit

final class FakeSourceFileIndex: SourceFileIndex {

    var locations: [String: [URL]] = [:]
    private(set) var roots: [URL] = []
    private(set) var preferredExtensions: [String] = []

    func locate(fileName: String, under root: URL, preferredExtension: String) -> [URL] {
        roots.append(root)
        preferredExtensions.append(preferredExtension)
        return locations[fileName] ?? []
    }
}
