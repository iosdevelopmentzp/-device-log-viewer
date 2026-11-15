import Foundation
import Testing
@testable import LogReaderKit

struct LogFileTitleTests {

    @Test func dropsTheLogPrefixAndExtension() {
        let url = URL(fileURLWithPath: "/tmp/log-2026.10.07-22:18:54.txt")

        #expect(LogFileTitle.title(for: url, prefix: "log-") == "2026.10.07-22:18:54")
    }

    @Test func keepsOtherNamesWithTheExtension() {
        let url = URL(fileURLWithPath: "/tmp/app.txt")

        #expect(LogFileTitle.title(for: url, prefix: "log-") == "app.txt")
    }

    @Test func emptyPrefixKeepsTheName() {
        let url = URL(fileURLWithPath: "/tmp/log-2026.10.07.txt")

        #expect(LogFileTitle.title(for: url, prefix: "") == "log-2026.10.07.txt")
    }

    @Test func nameEqualToThePrefixIsKept() {
        let url = URL(fileURLWithPath: "/tmp/log-.txt")

        #expect(LogFileTitle.title(for: url, prefix: "log-") == "log-.txt")
    }
}
