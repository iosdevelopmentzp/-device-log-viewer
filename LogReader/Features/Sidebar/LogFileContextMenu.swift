import LogReaderKit
import SwiftUI

struct LogFileContextMenu: View {

    let item: SidebarFileItem
    let model: SidebarViewModel
    let showsRemoveFromList: Bool

    var body: some View {
        Button("Open") { model.open(item) }
        Button("Open in New Window") { model.openInNewWindow(item) }
        Divider()
        Button("Show in Finder") { model.reveal(item) }
        Button("Open in Default App") { model.openInDefaultApp(item) }
        Divider()
        Button("Copy Path") { model.copyPath(item) }
        Button("Copy File Name") { model.copyFileName(item) }
        Button("Copy File") { model.copyFile(item) }
        Divider()
        Button("Save a Copy…") { model.saveCopy(of: item) }
        ShareLink(item: item.url) {
            Text("Share…")
        }
        if showsRemoveFromList {
            Divider()
            Button("Remove from List") { model.removeFromList(item) }
        }
        if item.canDelete {
            Divider()
            Button("Move to Trash", role: .destructive) { model.trash(item) }
        }
    }
}
