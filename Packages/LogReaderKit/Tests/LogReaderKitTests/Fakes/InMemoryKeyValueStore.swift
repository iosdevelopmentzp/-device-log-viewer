import Foundation
import LogReaderKit

final class InMemoryKeyValueStore: KeyValueStore {

    private(set) var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func bool(forKey defaultName: String) -> Bool {
        values[defaultName] as? Bool ?? false
    }

    func double(forKey defaultName: String) -> Double {
        values[defaultName] as? Double ?? 0
    }

    func integer(forKey defaultName: String) -> Int {
        values[defaultName] as? Int ?? 0
    }

    func dictionary(forKey defaultName: String) -> [String: Any]? {
        values[defaultName] as? [String: Any]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }

    func register(defaults registrationDictionary: [String: Any]) {
        for (key, value) in registrationDictionary where values[key] == nil {
            values[key] = value
        }
    }
}
