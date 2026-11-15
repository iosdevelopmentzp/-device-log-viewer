import LogReaderKit
import SwiftUI

struct AppContainerContextMenu: View {

    let item: SidebarAppItem
    let model: SidebarViewModel

    var body: some View {
        Button("Show Logs Folder in Finder") { model.showLogsFolder(item) }
        Button("Copy Logs Folder Path") { model.copyLogsFolderPath(item) }
        Button("Copy Bundle ID") { model.copyBundleID(item) }
        if item.newestFileURL != nil {
            Divider()
            Button("Copy Latest File") { model.copyLatestFile(item) }
        }
        if item.canDelete {
            Divider()
            Button("Delete Older Files…", role: .destructive) { model.deleteOlderFiles(of: item) }
                .disabled(model.canDeleteOlderFiles(of: item) == false)
            Button("Delete All Logs…", role: .destructive) { model.deleteAllFiles(of: item) }
        }
    }
}
