import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct DeviceSubtitleTextTests {

    @Test func simulatorShowsTheRuntime() {
        #expect(DeviceSubtitleText.subtitle(for: device(kind: .simulator)) == "iOS 27.0.1")
    }

    @Test func physicalDeviceAddsTheConnection() {
        #expect(DeviceSubtitleText.subtitle(for: device(kind: .physical(.network))) == "iOS 27.0.1 · Wi-Fi")
        #expect(DeviceSubtitleText.subtitle(for: device(kind: .physical(.usb))) == "iOS 27.0.1 · USB")
    }

    @Test func unknownConnectionShowsOnlyTheRuntime() {
        #expect(DeviceSubtitleText.subtitle(for: device(kind: .physical(.unknown))) == "iOS 27.0.1")
    }

    private func device(kind: DeviceKind) -> SimulatorDevice {
        SimulatorDevice(
            udid: "X",
            name: "Test Phone",
            runtime: "iOS 27.0.1",
            isBooted: true,
            folderURL: URL(fileURLWithPath: "/tmp/X", isDirectory: true),
            apps: [],
            kind: kind
        )
    }
}
