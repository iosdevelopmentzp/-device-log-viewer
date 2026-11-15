import Foundation
import LogReaderKit
import Synchronization

final class FakeDevicectlRunner: DevicectlCommandRunning {

    struct FakeError: Error {}

    private struct State {
        var responses: [String: Data] = [:]
        var remoteFiles: [String: Data] = [:]
        var failingCommands: Set<String> = []
        var calls: [[String]] = []
    }

    private let state = Mutex(State())

    var calls: [[String]] {
        state.withLock { $0.calls }
    }

    func setResponse(_ json: String, for arguments: [String]) {
        state.withLock { $0.responses[arguments.joined(separator: " ")] = Data(json.utf8) }
    }

    func setRemoteFile(_ name: String, content: String?) {
        state.withLock { $0.remoteFiles[name] = content.map { Data($0.utf8) } }
    }

    func setFailing(_ command: String, _ isFailing: Bool) {
        state.withLock { state in
            if isFailing {
                state.failingCommands.insert(command)
            } else {
                state.failingCommands.remove(command)
            }
        }
    }

    func callCount(_ command: String) -> Int {
        calls.filter { Self.command(of: $0) == command }.count
    }

    func run(_ arguments: [String]) throws -> Data {
        try state.withLock { state in
            state.calls.append(arguments)
            let command = Self.command(of: arguments)
            guard state.failingCommands.contains(command) == false else { throw FakeError() }
            if let response = state.responses[arguments.joined(separator: " ")] {
                return response
            }
            switch command {
            case DevicectlFixtures.filesCommand:
                return Data(DevicectlFixtures.files(state.remoteFiles.map { ("Logs/\($0.key)", Int64($0.value.count)) }).utf8)
            case DevicectlFixtures.copyCommand:
                try copy(arguments, remoteFiles: state.remoteFiles)
                return Data("{}".utf8)
            default:
                throw FakeError()
            }
        }
    }
}

// MARK: - Private

private extension FakeDevicectlRunner {

    static func command(of arguments: [String]) -> String {
        arguments.prefix { $0.hasPrefix("--") == false }.joined(separator: " ")
    }

    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    func copy(_ arguments: [String], remoteFiles: [String: Data]) throws {
        guard let source = Self.value(after: "--source", in: arguments),
              let destination = Self.value(after: "--destination", in: arguments),
              let content = remoteFiles[(source as NSString).lastPathComponent] else { throw FakeError() }
        try content.write(to: URL(fileURLWithPath: destination))
    }
}
