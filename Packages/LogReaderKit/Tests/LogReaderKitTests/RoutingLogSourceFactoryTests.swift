import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct RoutingLogSourceFactoryTests {

    private let cacheRoot = URL(fileURLWithPath: "/tmp/RoutingLogSourceFactoryTests/Devices", isDirectory: true)
    private let fileFactory = FakeLogSourceFactory()

    @Test func fileInTheDeviceCacheGetsADeviceSource() {
        let url = cacheRoot.appendingPathComponent("PHONE-1/com.example.chat/log-1.txt")

        let source = makeFactory().makeSource(for: url, profile: ProfileFixtures.textTrailing)

        #expect(source is DeviceLogSource)
        #expect(source.url == url)
        #expect(fileFactory.sources.map(\.url) == [url])
        #expect(fileFactory.profiles == [ProfileFixtures.textTrailing])
    }

    @Test func otherFilesGetTheFileSource() {
        let outside = URL(fileURLWithPath: "/tmp/logs/log-1.txt")
        let tooShallow = cacheRoot.appendingPathComponent("PHONE-1/log-1.txt")

        #expect(makeFactory().makeSource(for: outside, profile: ProfileFixtures.textTrailing) is FakeLogSource)
        #expect(makeFactory().makeSource(for: tooShallow, profile: ProfileFixtures.textTrailing) is FakeLogSource)
    }

    @Test func locationIsReadFromThePath() {
        let url = cacheRoot.appendingPathComponent("PHONE-1/com.example.chat/log-1.txt")

        #expect(DeviceFileLocation.location(of: url, in: cacheRoot) == DeviceFileLocation(udid: "PHONE-1", bundleID: "com.example.chat", fileName: "log-1.txt"))
    }

    @Test func locationWorksBeforeTheFileExistsUnderPrivate() throws {
        let root = URL(fileURLWithPath: "/private/tmp/RoutingLogSourceFactoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("PHONE-1/com.example.chat/log-1.txt")

        #expect(DeviceFileLocation.location(of: url, in: root)?.fileName == "log-1.txt")
    }

    private func makeFactory() -> RoutingLogSourceFactory {
        RoutingLogSourceFactory(
            fileSourceFactory: fileFactory,
            deviceCacheRoot: cacheRoot,
            runner: FakeDevicectlRunner(),
            mirrorInterval: .seconds(1),
            isDeviceAccessEnabled: { true }
        )
    }
}
