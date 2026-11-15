import Foundation

@MainActor
public struct ExportEntries {

    private let dialogs: any FileDialogs
    private let writer: any FileWriter
    private let revealer: any FileRevealer

    public init(dialogs: any FileDialogs, writer: any FileWriter, revealer: any FileRevealer) {
        self.dialogs = dialogs
        self.writer = writer
        self.revealer = revealer
    }

    @discardableResult
    public func export(_ session: LogSession, format: ExportFormat) async -> Bool {
        let suggestedName = ExportFileName.suggested(for: session.url, format: format)
        guard let destination = dialogs.chooseSaveLocation(suggestedName: suggestedName) else { return false }
        let content = session.content
        let recordIndices = session.visible
        let writer = writer
        do {
            try await Task.detached(priority: .userInitiated) {
                let data = ExportEntriesEncoder.data(content: content, recordIndices: recordIndices, format: format)
                try writer.write(data, to: destination)
            }.value
            revealer.reveal(destination)
            return true
        } catch {
            dialogs.present(error)
            return false
        }
    }
}
