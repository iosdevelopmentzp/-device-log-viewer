import Foundation
import LogReaderKit

@MainActor
final class FakePasteboard: Pasteboard {

    private(set) var writtenTexts: [String] = []
    private(set) var writtenFileURLs: [URL] = []

    func write(text: String) {
        writtenTexts.append(text)
    }

    func write(fileURL: URL) {
        writtenFileURLs.append(fileURL)
    }
}
