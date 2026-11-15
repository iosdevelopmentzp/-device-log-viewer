import Foundation

public struct DevicectlDeviceList: Decodable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case result
    }

    private enum ResultKeys: String, CodingKey {
        case devices
    }

    public let devices: [DevicectlDevice]

    public var reachableIOSDevices: [DevicectlDevice] {
        devices.filter { $0.isIOS && $0.isReachable }
    }

    public init(from decoder: any Decoder) throws {
        let result = try decoder.container(keyedBy: CodingKeys.self).nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
        self.devices = try result.decodeIfPresent([DevicectlDevice].self, forKey: .devices) ?? []
    }
}
