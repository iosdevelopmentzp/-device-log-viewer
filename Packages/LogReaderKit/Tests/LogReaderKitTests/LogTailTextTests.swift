import Foundation
import Testing
@testable import LogReaderKit

struct LogTailTextTests {

    @Test func keepsTheLastLines() {
        #expect(LogTailText.lastLines(of: "1\n2\n3\n4\n", count: 2) == "3\n4")
        #expect(LogTailText.lastLines(of: "1\n2", count: 5) == "1\n2")
    }

    @Test func emptyLogGivesEmptyText() {
        #expect(LogTailText.lastLines(of: "", count: 200) == "")
    }
}
