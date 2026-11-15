import Foundation

public final class DataFileWriter: Sendable {

    public init() {}
}

// MARK: - FileWriter

extension DataFileWriter: FileWriter {

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
