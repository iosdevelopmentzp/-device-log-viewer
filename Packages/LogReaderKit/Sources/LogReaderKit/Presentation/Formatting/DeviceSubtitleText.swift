import Foundation
import LogReaderCore

public enum DeviceSubtitleText {

    private static let separator = " · "

    public static func subtitle(for device: SimulatorDevice) -> String {
        guard case let .physical(transport) = device.kind else { return device.runtime }
        return [device.runtime, transport.displayName]
            .filter { $0.isEmpty == false }
            .joined(separator: separator)
    }
}
