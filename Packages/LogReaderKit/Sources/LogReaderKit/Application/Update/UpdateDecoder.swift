import Foundation

public enum UpdateDecoder {

    private static let fieldSeparator: Character = "\u{1F}"

    public static func installedBuild(from data: Data) -> InstalledBuild? {
        try? jsonDecoder().decode(InstalledBuild.self, from: data)
    }

    public static func status(from data: Data) -> UpdateStatus? {
        try? jsonDecoder().decode(UpdateStatus.self, from: data)
    }

    public static func commits(fromGitLog output: String) -> [UpdateCommit] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let fields = line.split(separator: fieldSeparator, maxSplits: 1, omittingEmptySubsequences: false)
                guard fields.count == 2, fields[0].isEmpty == false else { return nil }
                return UpdateCommit(shortHash: String(fields[0]), subject: String(fields[1]))
            }
    }
}

// MARK: - Private

private extension UpdateDecoder {

    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
