import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct RelativeTimeTextTests {

    @Test func pastDatesAreRelative() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(RelativeTimeText.text(for: now.addingTimeInterval(-120), relativeTo: now) == "2m ago")
        #expect(RelativeTimeText.text(for: now, relativeTo: now) == "now")
        #expect(RelativeTimeText.text(for: now.addingTimeInterval(60), relativeTo: now) == "now")
    }
}
