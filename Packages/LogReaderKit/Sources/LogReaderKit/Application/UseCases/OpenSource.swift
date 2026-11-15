import Foundation
import LogReaderCore

@MainActor
public struct OpenSource {

    private let index: any SourceFileIndex
    private let opener: any SourceOpener
    private let dialogs: any FileDialogs
    private let profiles: ProfileRegistry

    public init(index: any SourceFileIndex, opener: any SourceOpener, dialogs: any FileDialogs, profiles: ProfileRegistry) {
        self.index = index
        self.opener = opener
        self.dialogs = dialogs
        self.profiles = profiles
    }

    public func open(_ record: LogRecord, profile: LogProfile) {
        do {
            try openOrThrow(record, profile: profile)
        } catch {
            dialogs.present(error)
        }
    }
}

// MARK: - Private

private extension OpenSource {

    func openOrThrow(_ record: LogRecord, profile: LogProfile) throws {
        guard let reference = profile.sourceReference(of: record) else { throw OpenSourceError.noSource }
        guard let root = profiles.projectRoot(for: profile) else { throw OpenSourceError.noProjectRoot }
        let fileExtension = profile.source.fileExtension
        guard let url = index.locate(fileName: reference.fileName, under: root, preferredExtension: fileExtension).first else {
            let displayName = (reference.fileName as NSString).pathExtension.isEmpty
                ? reference.fileName + "." + fileExtension
                : reference.fileName
            throw OpenSourceError.fileNotFound(fileName: displayName, root: root)
        }
        do {
            try opener.open(url, line: reference.line, editor: profile.source)
        } catch {
            throw OpenSourceError.openFailed(error)
        }
    }
}
