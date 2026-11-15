import Foundation
import Testing
@testable import LogReaderKit

struct DeltaTextFormatterTests {

    @Test func formatsMillisecondsSecondsAndMinutes() {
        #expect(DeltaTextFormatter.text(from: 10, to: 10.25) == "+250ms")
        #expect(DeltaTextFormatter.text(from: 10, to: 11.5) == "+1.50s")
        #expect(DeltaTextFormatter.text(from: 0, to: 125) == "+2m05s")
    }

    @Test func missingTimestampGivesEmptyText() {
        #expect(DeltaTextFormatter.text(from: nil, to: 1) == "")
        #expect(DeltaTextFormatter.text(from: 1, to: nil) == "")
    }
}
