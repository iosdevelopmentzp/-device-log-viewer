import Foundation

public protocol DevicectlCommandRunning: Sendable {
    func run(_ arguments: [String]) throws -> Data
}

extension DevicectlCommandRunning {

    func decode<Value: Decodable>(_ type: Value.Type, arguments: [String]) throws -> Value {
        try JSONDecoder().decode(type, from: run(arguments))
    }
}
