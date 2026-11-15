import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct DeviceLogSourceTests {

    @Test func forwardsTheCacheEventsAfterTheFirstCopy() async throws {
        let runner = FakeDevicectlRunner()
        let fileName = "log-1.txt"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DeviceLogSourceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cacheURL = folder.appendingPathComponent(fileName)
        let cacheSource = FakeLogSource(url: cacheURL)
        let mirror = DeviceFileMirror(
            location: DeviceFileLocation(udid: "PHONE-1", bundleID: "com.example.chat", fileName: fileName),
            logsPath: "Library/Application Support/Logs",
            cacheURL: cacheURL,
            runner: runner,
            interval: .seconds(10),
            isEnabled: { true }
        )
        let source = DeviceLogSource(url: cacheURL, mirror: mirror, cacheSource: cacheSource)
        runner.setRemoteFile(fileName, content: "AAA")

        var iterator = source.events().makeAsyncIterator()
        cacheSource.send(.reset)
        let event = await iterator.next()

        guard case .reset = event else {
            Issue.record("Expected .reset, got \(String(describing: event))")
            return
        }
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))

        source.stop()
        #expect(cacheSource.isStopped)
    }
}
