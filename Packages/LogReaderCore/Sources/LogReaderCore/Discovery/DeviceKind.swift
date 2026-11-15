public enum DeviceKind: Hashable, Sendable {
    case simulator
    case physical(DeviceTransport)
}
