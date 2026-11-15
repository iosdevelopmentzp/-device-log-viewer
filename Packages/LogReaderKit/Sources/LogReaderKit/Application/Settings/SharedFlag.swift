import Foundation
import Synchronization

public final class SharedFlag: Sendable {

    private let state: Mutex<Bool>

    public var isOn: Bool {
        state.withLock { $0 }
    }

    public init(isOn: Bool) {
        self.state = Mutex(isOn)
    }

    public func set(_ isOn: Bool) {
        state.withLock { $0 = isOn }
    }
}
