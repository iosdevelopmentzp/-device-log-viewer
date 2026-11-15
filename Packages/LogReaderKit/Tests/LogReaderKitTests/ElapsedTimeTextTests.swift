import Foundation
import Testing
@testable import LogReaderKit

struct ElapsedTimeTextTests {

    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func formatsMinutesAndSeconds() {
        #expect(ElapsedTimeText.text(from: start, to: start.addingTimeInterval(3.9)) == "0:03")
        #expect(ElapsedTimeText.text(from: start, to: start.addingTimeInterval(80)) == "1:20")
        #expect(ElapsedTimeText.text(from: start, to: start.addingTimeInterval(725)) == "12:05")
    }

    @Test func clockBeforeTheStartShowsZero() {
        #expect(ElapsedTimeText.text(from: start, to: start.addingTimeInterval(-5)) == "0:00")
    }
}
