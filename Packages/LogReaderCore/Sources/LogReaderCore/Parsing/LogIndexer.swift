import Foundation

public struct LogIndexer: Sendable {

    public private(set) var format: LogFileFormat?

    private let framing: FramingRule
    private let grammar: LogEntryGrammar
    private var pending = Data()
    private var pendingOffset = 0
    private var nextChunkIndex = 0

    public init(profile: LogProfile) {
        self.framing = profile.framing
        self.grammar = LogEntryGrammar(profile: profile)
    }

    public mutating func consume(_ data: Data) -> LogBatch? {
        guard data.isEmpty == false else { return nil }
        if pending.isEmpty {
            pending = data.startIndex == 0 ? data : Data(data)
        } else {
            pending.append(data)
        }
        if format == nil {
            guard detectFormat() else { return nil }
        }
        guard let format else { return nil }
        return takeCompleteEntries(format: format)
    }
}

// MARK: - Private

private extension LogIndexer {

    mutating func detectFormat() -> Bool {
        switch framing {
        case .header:
            return detectHeader()
        case .separator:
            format = framing.separatorByte.map(LogFileFormat.separated) ?? .lines
            return true
        case .lines:
            format = .lines
            return true
        }
    }

    mutating func detectHeader() -> Bool {
        guard let newlineIndex = pending.firstIndex(of: LogFileFormat.newline) else {
            guard pending.count > LogFileFormat.maxHeaderLookup else { return false }
            format = .lines
            return true
        }
        let detected = LogFileFormat.detect(fromFirstLine: pending.prefix(upTo: newlineIndex))
        if case .separated = detected {
            let headerLength = newlineIndex + 1
            pending = Data(pending.suffix(from: headerLength))
            pendingOffset += headerLength
        }
        format = detected
        return true
    }

    mutating func takeCompleteEntries(format: LogFileFormat) -> LogBatch? {
        guard let lastTerminator = pending.lastIndex(of: format.terminator) else { return nil }
        let completeLength = lastTerminator + 1
        let chunk = completeLength == pending.count ? pending : Data(pending.prefix(completeLength))
        let baseOffset = pendingOffset
        pending = completeLength == pending.count ? Data() : Data(pending.suffix(from: completeLength))
        pendingOffset += completeLength

        let records = LogRecordBuilder.records(
            in: chunk,
            chunkIndex: nextChunkIndex,
            baseOffset: baseOffset,
            format: format,
            grammar: grammar,
            joinsUnrecognizedLines: framing.joinsUnrecognizedLines
        )
        guard records.isEmpty == false else { return nil }
        let batch = LogBatch(chunkIndex: nextChunkIndex, chunk: chunk, records: records)
        nextChunkIndex += 1
        return batch
    }
}
