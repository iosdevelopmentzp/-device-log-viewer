import LogReaderCore

public extension DeviceTransport {

    var displayName: String {
        switch self {
        case .usb: "USB"
        case .network: "Wi-Fi"
        case .unknown: ""
        }
    }
}
