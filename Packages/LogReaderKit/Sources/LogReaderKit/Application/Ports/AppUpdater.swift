import Foundation

public protocol AppUpdater: Sendable {
    func installed() -> InstalledBuild?
    func check(installed: InstalledBuild) throws -> [UpdateCommit]
    func start() throws
    func status() -> UpdateStatus?
    func clearStatus()
    func log() -> String
    func isUpdateRunning() -> Bool
}
