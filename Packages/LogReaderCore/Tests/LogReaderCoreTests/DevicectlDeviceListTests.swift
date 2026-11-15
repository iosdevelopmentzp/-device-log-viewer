import Foundation
import Testing
@testable import LogReaderCore

struct DevicectlDeviceListTests {

    private static let json = """
    {
      "info": { "commandType": "devicectl.list.devices", "outcome": "success" },
      "result": {
        "devices": [
          {
            "identifier": "AAAA-WATCH",
            "connectionProperties": { "pairingState": "paired", "tunnelState": "connected", "transportType": "localNetwork" },
            "deviceProperties": { "name": "Test Watch", "osVersionNumber": "11.0" },
            "hardwareProperties": { "platform": "watchOS", "marketingName": "Apple Watch" }
          },
          {
            "identifier": "BBBB-OFFLINE",
            "connectionProperties": { "pairingState": "paired", "tunnelState": "unavailable" },
            "deviceProperties": { "name": "Old Phone", "osVersionNumber": "26.1" },
            "hardwareProperties": { "platform": "iOS", "marketingName": "iPhone 12" }
          },
          {
            "identifier": "CCCC-WIFI",
            "connectionProperties": { "pairingState": "paired", "tunnelState": "connected", "transportType": "localNetwork" },
            "deviceProperties": { "name": "Test Phone", "osVersionNumber": "27.0.1" },
            "hardwareProperties": { "platform": "iOS", "marketingName": "iPhone 15" }
          },
          {
            "identifier": "DDDD-USB",
            "connectionProperties": { "pairingState": "paired", "tunnelState": "disconnected", "transportType": "wired" },
            "deviceProperties": { "name": "Cable Phone", "osVersionNumber": "26.6" },
            "hardwareProperties": { "platform": "iOS", "marketingName": "iPhone 14" }
          },
          {
            "identifier": "EEEE-NOTRANSPORT",
            "connectionProperties": { "tunnelState": "disconnected" },
            "deviceProperties": { "name": "Quiet Phone", "osVersionNumber": "26.0" },
            "hardwareProperties": { "platform": "iOS" }
          }
        ]
      }
    }
    """

    @Test func decodesEveryDevice() throws {
        let list = try Self.decode()
        let phone = try #require(list.devices.first { $0.identifier == "CCCC-WIFI" })

        #expect(list.devices.count == 5)
        #expect(phone.name == "Test Phone")
        #expect(phone.osVersion == "27.0.1")
        #expect(phone.platform == "iOS")
        #expect(phone.marketingName == "iPhone 15")
        #expect(phone.tunnelState == "connected")
    }

    @Test func keepsOnlyReachableIOSDevices() throws {
        let list = try Self.decode()

        #expect(list.reachableIOSDevices.map(\.identifier) == ["CCCC-WIFI", "DDDD-USB", "EEEE-NOTRANSPORT"])
    }

    @Test func mapsTheTransport() throws {
        let list = try Self.decode()
        let transports = Dictionary(uniqueKeysWithValues: list.devices.map { ($0.identifier, $0.transport) })

        #expect(transports["CCCC-WIFI"] == .network)
        #expect(transports["DDDD-USB"] == .usb)
        #expect(transports["EEEE-NOTRANSPORT"] == .unknown)
    }

    @Test func missingDevicesGiveAnEmptyList() throws {
        let data = Data(#"{"result": {}}"#.utf8)

        #expect(try JSONDecoder().decode(DevicectlDeviceList.self, from: data).devices.isEmpty)
    }

    @Test func missingResultThrows() {
        let data = Data(#"{"info": {"outcome": "failed"}}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DevicectlDeviceList.self, from: data)
        }
    }

    private static func decode() throws -> DevicectlDeviceList {
        try JSONDecoder().decode(DevicectlDeviceList.self, from: Data(json.utf8))
    }
}
