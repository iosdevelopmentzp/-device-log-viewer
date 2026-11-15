import Foundation

extension UserDefaults: KeyValueStore {}

public extension KeyValueStore where Self == UserDefaults {

    static var standardDefaults: UserDefaults { .standard }
}
