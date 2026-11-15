import Foundation
@testable import LogReaderKit

enum UpdateFixtures {

    static let installedCommit = "4bf0b5d1c2a3e4f5a6b7c8d9e0f1a2b3c4d5e6f7"
    static let startedAt = Date(timeIntervalSince1970: 1_800_000_000)

    static let installed = InstalledBuild(
        commit: installedCommit,
        branch: "main",
        source: "/tmp/source",
        installedAt: startedAt
    )

    static let commits = [
        UpdateCommit(shortHash: "aaaaaaa", subject: "Add a button"),
        UpdateCommit(shortHash: "bbbbbbb", subject: "Fix a crash")
    ]

    static func status(_ phase: UpdatePhase, commit: String?, message: String?) -> UpdateStatus {
        UpdateStatus(phase: phase, startedAt: startedAt, commit: commit, message: message)
    }
}
