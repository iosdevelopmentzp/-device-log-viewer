import Foundation

public struct DevicectlFile: Decodable, Hashable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case relativePath
        case metadata
        case resources
    }

    private enum MetadataKeys: String, CodingKey {
        case size
        case lastModDate
    }

    private enum ResourceKeys: String, CodingKey {
        case isDirectory
    }

    public let relativePath: String
    public let size: Int64
    public let lastModDate: Date?
    public let isDirectory: Bool

    public var name: String {
        relativePath.split(separator: "/").last.map(String.init) ?? relativePath
    }

    private static let fileNameDateParts = 6

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let metadata = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata)
        let resources = try? container.nestedContainer(keyedBy: ResourceKeys.self, forKey: .resources)
        self.relativePath = try container.decode(String.self, forKey: .relativePath)
        self.size = (try? metadata?.decodeIfPresent(Int64.self, forKey: .size)) ?? 0
        self.lastModDate = (try? metadata?.decodeIfPresent(String.self, forKey: .lastModDate)).flatMap(Self.date(iso8601:))
        self.isDirectory = (try? resources?.decodeIfPresent(Bool.self, forKey: .isDirectory)) ?? false
    }

    public func createdAt(fileNamePrefix: String) -> Date {
        Self.date(fromFileName: name, prefix: fileNamePrefix) ?? lastModDate ?? .distantPast
    }
}

// MARK: - Private

private extension DevicectlFile {

    static func date(fromFileName name: String, prefix: String) -> Date? {
        guard prefix.isEmpty == false, name.hasPrefix(prefix) else { return nil }
        let numbers = name
            .dropFirst(prefix.count)
            .split { $0.isNumber == false }
            .compactMap { Int($0) }
        guard numbers.count >= fileNameDateParts else { return nil }
        let components = DateComponents(
            year: numbers[0],
            month: numbers[1],
            day: numbers[2],
            hour: numbers[3],
            minute: numbers[4],
            second: numbers[5]
        )
        return Calendar.current.date(from: components)
    }

    static func date(iso8601 text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(text)
    }
}
