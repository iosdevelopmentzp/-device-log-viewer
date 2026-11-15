import Foundation
import LogReaderCore

public struct FileLogProfileLoader: Sendable {

    public init() {}
}

// MARK: - LogProfileLoader

extension FileLogProfileLoader: LogProfileLoader {

    public func load(projectRoot: URL) -> ProfileLoadResult {
        let url = ProjectProfile.profileURL(in: projectRoot)
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        let modifiedAt = modificationDate(projectRoot: projectRoot)
        do {
            let data = try Data(contentsOf: url)
            let profile = try JSONDecoder().decode(LogProfile.self, from: data)
            try profile.validate()
            return .loaded(profile, modifiedAt: modifiedAt ?? Date())
        } catch let error as LogProfileError {
            return .failed(error.localizedDescription, modifiedAt: modifiedAt)
        } catch let error as DecodingError {
            return .failed(Self.describe(error), modifiedAt: modifiedAt)
        } catch {
            return .failed(error.localizedDescription, modifiedAt: modifiedAt)
        }
    }

    public func modificationDate(projectRoot: URL) -> Date? {
        let url = ProjectProfile.profileURL(in: projectRoot)
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    public func writeExample(projectRoot: URL) throws {
        let url = ProjectProfile.profileURL(in: projectRoot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(ExampleProfileText.json.utf8).write(to: url, options: .withoutOverwriting)
    }
}

// MARK: - Private

private extension FileLogProfileLoader {

    static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            "Missing key “\(key.stringValue)” at \(path(context))."
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            "Wrong value at \(path(context)): \(context.debugDescription)"
        case .dataCorrupted(let context):
            context.debugDescription
        @unknown default:
            error.localizedDescription
        }
    }

    static func path(_ context: DecodingError.Context) -> String {
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "the top level" : path
    }
}
