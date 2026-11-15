import Foundation
import Testing
@testable import LogReaderKit

struct ExportFileNameTests {

    @Test func nameAddsTheSuffixAndTheFormatExtension() {
        let url = URL(fileURLWithPath: "/tmp/logs/log-2026.10.07-22:18:54.txt")

        #expect(ExportFileName.suggested(for: url, format: .log) == "log-2026.10.07-22-18-54-filtered.txt")
        #expect(ExportFileName.suggested(for: url, format: .json) == "log-2026.10.07-22-18-54-filtered.json")
    }

    @Test func nameWithoutExtensionStillGetsOne() {
        let url = URL(fileURLWithPath: "/tmp/logs/session")

        #expect(ExportFileName.suggested(for: url, format: .log) == "session-filtered.txt")
    }
}
