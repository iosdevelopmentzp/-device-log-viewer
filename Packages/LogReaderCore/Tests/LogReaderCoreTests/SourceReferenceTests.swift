import Foundation
import Testing
@testable import LogReaderCore

struct SourceReferenceTests {

    @Test func nameAndLine() {
        #expect(SourceReference.parse("ApiService:229") == SourceReference(fileName: "ApiService", line: 229))
    }

    @Test func nameWithoutLine() {
        #expect(SourceReference.parse("ApiService") == SourceReference(fileName: "ApiService", line: nil))
    }

    @Test func textAfterTheLastColonThatIsNotANumberKeepsTheWholeString() {
        #expect(SourceReference.parse("Api:Service") == SourceReference(fileName: "Api:Service", line: nil))
        #expect(SourceReference.parse("ApiService:") == SourceReference(fileName: "ApiService:", line: nil))
    }

    @Test func onlyTheLastColonSplits() {
        #expect(SourceReference.parse("Api:Service:12") == SourceReference(fileName: "Api:Service", line: 12))
    }

    @Test func emptyNameGivesNil() {
        #expect(SourceReference.parse("") == nil)
        #expect(SourceReference.parse(":12") == nil)
    }

    @Test func profileExposesTheReferenceOfARecord() {
        let profile = ProfileFixtures.textTrailing
        let record = LogRecord(
            offset: 0,
            chunk: 0,
            start: 0,
            length: 1,
            metadataRange: 0..<0,
            level: nil,
            timestamp: nil,
            message: "",
            detailPreview: "",
            attributes: [.none, .none, .text("Store:20")],
            isStructured: true
        )

        #expect(profile.sourceReference(of: record) == SourceReference(fileName: "Store", line: 20))
        #expect(profile.source(of: record) == "Store:20")
        #expect(ProfileFixtures.regex.sourceReference(of: record) == nil)
    }
}
