import Foundation
import Testing
@testable import LogReaderKit

struct UpdateDecoderTests {

    @Test func decodesInstalledBuild() throws {
        let json = """
        {"commit": "4bf0b5d1c2a3", "branch": "main", "source": "/Users/me/Library/Application Support/LogReader/source", "installedAt": "2026-11-07T10:15:00Z"}
        """

        let build = try #require(UpdateDecoder.installedBuild(from: Data(json.utf8)))

        #expect(build.commit == "4bf0b5d1c2a3")
        #expect(build.shortCommit == "4bf0b5d")
        #expect(build.branch == "main")
        #expect(build.source == "/Users/me/Library/Application Support/LogReader/source")
        #expect(build.installedAt == Date(timeIntervalSince1970: 1_794_046_500))
    }

    @Test func decodesStatusWithNulls() throws {
        let json = """
        {"phase": "building", "startedAt": "2026-11-07T10:15:00Z", "commit": null, "message": null}
        """

        let status = try #require(UpdateDecoder.status(from: Data(json.utf8)))

        #expect(status == UpdateStatus(phase: .building, startedAt: Date(timeIntervalSince1970: 1_794_046_500), commit: nil, message: nil))
    }

    @Test func decodesFailedStatusWithMessage() throws {
        let json = """
        {"phase": "failed", "startedAt": "2026-11-07T10:15:00Z", "commit": null, "message": "Could not get the changes"}
        """

        let status = try #require(UpdateDecoder.status(from: Data(json.utf8)))

        #expect(status.phase == .failed)
        #expect(status.message == "Could not get the changes")
    }

    @Test func rejectsBrokenFiles() {
        #expect(UpdateDecoder.status(from: Data("{\"phase\": \"waiting\"".utf8)) == nil)
        #expect(UpdateDecoder.status(from: Data("{\"phase\": \"unknown\", \"startedAt\": \"2026-11-07T10:15:00Z\"}".utf8)) == nil)
        #expect(UpdateDecoder.installedBuild(from: Data("{}".utf8)) == nil)
    }

    @Test func parsesGitLogLines() {
        let output = "aaaaaaa\u{1F}Add a button\nbbbbbbb\u{1F}Fix: a · crash\u{1F}x\n\nbroken line\n"

        #expect(UpdateDecoder.commits(fromGitLog: output) == [
            UpdateCommit(shortHash: "aaaaaaa", subject: "Add a button"),
            UpdateCommit(shortHash: "bbbbbbb", subject: "Fix: a · crash\u{1F}x")
        ])
        #expect(UpdateDecoder.commits(fromGitLog: "").isEmpty)
    }
}
