import Foundation

public protocol KeyValueStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func double(forKey defaultName: String) -> Double
    func integer(forKey defaultName: String) -> Int
    func dictionary(forKey defaultName: String) -> [String: Any]?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
    func register(defaults registrationDictionary: [String: Any])
}
