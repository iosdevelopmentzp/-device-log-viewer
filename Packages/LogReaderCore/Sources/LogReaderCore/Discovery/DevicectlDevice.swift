import Foundation

public struct DevicectlDevice: Decodable, Hashable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case identifier
        case deviceProperties
        case hardwareProperties
        case connectionProperties
    }

    private enum DeviceKeys: String, CodingKey {
        case name
        case osVersionNumber
    }

    private enum HardwareKeys: String, CodingKey {
        case platform
        case marketingName
    }

    private enum ConnectionKeys: String, CodingKey {
        case tunnelState
        case transportType
    }

    public let identifier: String
    public let name: String
    public let osVersion: String
    public let platform: String
    public let marketingName: String
    public let tunnelState: String
    public let transportType: String?

    public var isIOS: Bool { platform == Self.iOSPlatform }

    public var isReachable: Bool { tunnelState != Self.unavailableTunnelState }

    public var transport: DeviceTransport {
        switch transportType {
        case Self.wiredTransport: .usb
        case Self.networkTransport: .network
        default: .unknown
        }
    }

    private static let iOSPlatform = "iOS"
    private static let unavailableTunnelState = "unavailable"
    private static let wiredTransport = "wired"
    private static let networkTransport = "localNetwork"

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let device = try? container.nestedContainer(keyedBy: DeviceKeys.self, forKey: .deviceProperties)
        let hardware = try? container.nestedContainer(keyedBy: HardwareKeys.self, forKey: .hardwareProperties)
        let connection = try? container.nestedContainer(keyedBy: ConnectionKeys.self, forKey: .connectionProperties)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.name = (try? device?.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.osVersion = (try? device?.decodeIfPresent(String.self, forKey: .osVersionNumber)) ?? ""
        self.platform = (try? hardware?.decodeIfPresent(String.self, forKey: .platform)) ?? ""
        self.marketingName = (try? hardware?.decodeIfPresent(String.self, forKey: .marketingName)) ?? ""
        self.tunnelState = (try? connection?.decodeIfPresent(String.self, forKey: .tunnelState)) ?? Self.unavailableTunnelState
        self.transportType = try? connection?.decodeIfPresent(String.self, forKey: .transportType)
    }
}
