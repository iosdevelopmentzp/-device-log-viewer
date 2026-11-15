import Foundation

public struct SimulatorDevice: Identifiable, Hashable, Sendable {
    public let udid: String
    public let name: String
    public let runtime: String
    public let isBooted: Bool
    public let folderURL: URL
    public let apps: [AppLogContainer]
    public let kind: DeviceKind

    public var id: String { udid }

    public var isPhysical: Bool { kind != .simulator }

    public init(
        udid: String,
        name: String,
        runtime: String,
        isBooted: Bool,
        folderURL: URL,
        apps: [AppLogContainer],
        kind: DeviceKind
    ) {
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.isBooted = isBooted
        self.folderURL = folderURL
        self.apps = apps
        self.kind = kind
    }
}
