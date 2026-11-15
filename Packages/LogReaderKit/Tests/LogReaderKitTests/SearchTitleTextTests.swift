import Testing
@testable import LogReaderKit

struct SearchTitleTextTests {

    @Test func keepsShortText() {
        #expect(SearchTitleText.shortened("timeout") == "timeout")
        #expect(SearchTitleText.shortened(String(repeating: "a", count: 40)) == String(repeating: "a", count: 40))
    }

    @Test func shortensLongTextWithAnEllipsis() {
        #expect(SearchTitleText.shortened(String(repeating: "a", count: 41)) == String(repeating: "a", count: 40) + "…")
    }
}
