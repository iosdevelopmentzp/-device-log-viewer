import Foundation

@MainActor
public struct FileActions {

    private let pasteboard: any Pasteboard
    private let revealer: any FileRevealer
    private let dialogs: any FileDialogs
    private let copier: any FileCopier

    public init(
        pasteboard: any Pasteboard,
        revealer: any FileRevealer,
        dialogs: any FileDialogs,
        copier: any FileCopier
    ) {
        self.pasteboard = pasteboard
        self.revealer = revealer
        self.dialogs = dialogs
        self.copier = copier
    }

    public func reveal(_ url: URL) {
        revealer.reveal(url)
    }

    public func openInDefaultApp(_ url: URL) {
        revealer.open(url)
    }

    public func openFolder(_ url: URL) {
        revealer.open(url)
    }

    public func copyPath(_ url: URL) {
        pasteboard.write(text: url.path)
    }

    public func copyFileName(_ url: URL) {
        pasteboard.write(text: url.lastPathComponent)
    }

    public func copyFile(_ url: URL) {
        pasteboard.write(fileURL: url)
    }

    public func copyText(_ text: String) {
        pasteboard.write(text: text)
    }

    public func saveCopy(of url: URL) {
        guard let destination = dialogs.chooseSaveLocation(suggestedName: Self.shareableName(for: url)) else { return }
        do {
            try copier.copy(url, to: destination, replacing: true)
            revealer.reveal(destination)
        } catch {
            dialogs.present(error)
        }
    }
}

// MARK: - Private

private extension FileActions {

    static func shareableName(for url: URL) -> String {
        url.lastPathComponent.replacingOccurrences(of: ":", with: "-")
    }
}
