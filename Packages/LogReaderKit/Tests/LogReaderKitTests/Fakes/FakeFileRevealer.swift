import Foundation
import LogReaderKit

@MainActor
final class FakeFileRevealer: FileRevealer {

    private(set) var revealedURLs: [URL] = []
    private(set) var openedURLs: [URL] = []

    func reveal(_ url: URL) {
        revealedURLs.append(url)
    }

    func open(_ url: URL) {
        openedURLs.append(url)
    }
}
