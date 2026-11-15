import Foundation
import LogReaderCore

@MainActor
public struct DeleteLogFiles {

    private let trasher: any FileTrasher
    private let dialogs: any FileDialogs

    private static let confirmTitle = "Move to Trash"
    private static let confirmMessage = "You can put the files back from the Trash in Finder."

    public init(trasher: any FileTrasher, dialogs: any FileDialogs) {
        self.trasher = trasher
        self.dialogs = dialogs
    }

    public func trash(_ url: URL) -> [URL] {
        trashAll([url])
    }

    public func deleteOlderFiles(of app: AppLogContainer) -> [URL] {
        let urls = LogCleanupPolicy.olderFiles(of: app)
        return confirmAndTrash(urls, title: Self.title(count: urls.count, kind: "older log", owner: app.bundleID))
    }

    public func deleteAllFiles(of app: AppLogContainer) -> [URL] {
        let urls = LogCleanupPolicy.allFiles(of: app)
        return confirmAndTrash(urls, title: Self.title(count: urls.count, kind: "log", owner: app.bundleID))
    }

    public func deleteAllFiles(of device: SimulatorDevice) -> [URL] {
        guard device.isPhysical == false else { return [] }
        let urls = LogCleanupPolicy.allFiles(of: device)
        return confirmAndTrash(urls, title: Self.title(count: urls.count, kind: "log", owner: device.name))
    }
}

// MARK: - Private

private extension DeleteLogFiles {

    func confirmAndTrash(_ urls: [URL], title: String) -> [URL] {
        guard urls.isEmpty == false else { return [] }
        guard dialogs.confirm(title: title, message: Self.confirmMessage, confirmTitle: Self.confirmTitle) else { return [] }
        return trashAll(urls)
    }

    func trashAll(_ urls: [URL]) -> [URL] {
        var trashed: [URL] = []
        for url in urls {
            do {
                try trasher.trash(url)
                trashed.append(url)
            } catch {
                dialogs.present(error)
                break
            }
        }
        return trashed
    }

    static func title(count: Int, kind: String, owner: String) -> String {
        let noun = count == 1 ? "file" : "files"
        return "Move \(count) \(kind) \(noun) of \(owner) to Trash?"
    }
}
