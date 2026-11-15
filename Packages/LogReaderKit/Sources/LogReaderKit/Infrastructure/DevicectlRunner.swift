import Foundation

public final class DevicectlRunner: Sendable {

    private let timeout: DispatchTimeInterval

    private static let xcrunPath = "/usr/bin/xcrun"

    public init(timeout: DispatchTimeInterval) {
        self.timeout = timeout
    }
}

// MARK: - DevicectlCommandRunning

extension DevicectlRunner: DevicectlCommandRunning {

    public func run(_ arguments: [String]) throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: Self.xcrunPath) else { throw DevicectlError.toolMissing }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogReader-devicectl-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.xcrunPath)
        process.arguments = ["devicectl"] + arguments + ["--json-output", outputURL.path, "-q"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()

        guard finished.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            throw DevicectlError.timedOut
        }
        guard process.terminationStatus == 0 else { throw DevicectlError.failed(status: process.terminationStatus) }
        return try Data(contentsOf: outputURL)
    }
}
