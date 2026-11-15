import Foundation

@MainActor
public struct CopyEntries {

    private let pasteboard: any Pasteboard

    public init(pasteboard: any Pasteboard) {
        self.pasteboard = pasteboard
    }

    public func copy(recordIndices: [Int], from session: LogSession) {
        let text = recordIndices
            .compactMap(session.record(at:))
            .map(session.text(of:))
            .joined(separator: "\n")
        pasteboard.write(text: text)
    }

    public func copySelection(of session: LogSession) {
        copy(recordIndices: session.selectedRecords, from: session)
    }

    public func copyVisible(of session: LogSession) {
        copy(recordIndices: session.visible, from: session)
    }

    public func copyJSON(recordIndex: Int, from session: LogSession) {
        guard let record = session.record(at: recordIndex) else { return }
        let json = EntryJSONEncoder.json(number: recordIndex + 1, record: record, text: session.text(of: record), profile: session.profile)
        pasteboard.write(text: json)
    }

    public func copy(text: String) {
        pasteboard.write(text: text)
    }
}
