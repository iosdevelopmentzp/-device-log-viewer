import Foundation
import LogReaderCore

public enum ExportEntriesEncoder {

    private static let headerSeparator: UInt8 = 0x1E
    private static let newline = UInt8(ascii: "\n")
    private static let header = Data("{\"v\":1,\"sep\":\"\\u001e\"}\n".utf8)

    public static func data(content: LogContent, recordIndices: [Int], format: ExportFormat) -> Data {
        switch format {
        case .log: logData(content: content, recordIndices: recordIndices)
        case .json: jsonData(content: content, recordIndices: recordIndices)
        }
    }

    public static func logData(content: LogContent, recordIndices: [Int]) -> Data {
        var data = Data()
        var separator: UInt8?
        switch content.profile.framing {
        case .header:
            data = header
            separator = headerSeparator
        case .separator(let text):
            separator = text.utf8.first
        case .lines:
            separator = nil
        }
        for record in records(in: content, at: recordIndices) {
            content.withBytes(of: record) { data.append(contentsOf: $0) }
            data.append(newline)
            if let separator {
                data.append(separator)
            }
        }
        return data
    }

    public static func jsonData(content: LogContent, recordIndices: [Int]) -> Data {
        let entries = recordIndices.compactMap { index -> String? in
            guard content.records.indices.contains(index) else { return nil }
            let record = content.records[index]
            return EntryJSONEncoder.json(number: index + 1, record: record, text: content.text(of: record), profile: content.profile)
        }
        guard entries.isEmpty == false else { return Data("[]".utf8) }
        return Data(("[\n" + entries.joined(separator: ",\n") + "\n]").utf8)
    }
}

// MARK: - Private

private extension ExportEntriesEncoder {

    static func records(in content: LogContent, at indices: [Int]) -> [LogRecord] {
        indices.compactMap { content.records.indices.contains($0) ? content.records[$0] : nil }
    }
}
