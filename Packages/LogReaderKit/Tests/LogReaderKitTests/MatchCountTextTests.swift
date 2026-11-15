import Testing
@testable import LogReaderKit

struct MatchCountTextTests {

    @Test func describesTheResult() {
        #expect(MatchCountText.text(for: .count(12)) == "12 matches")
        #expect(MatchCountText.text(for: .count(1)) == "1 match")
        #expect(MatchCountText.text(for: .count(0)) == "0 matches")
        #expect(MatchCountText.text(for: .skipped) == "skipped")
        #expect(MatchCountText.text(for: nil) == "")
    }
}
