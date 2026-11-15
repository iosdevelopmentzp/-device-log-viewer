import LogReaderKit
import SwiftUI

struct DeviceContextMenu: View {

    let item: SidebarDeviceItem
    let model: SidebarViewModel

    var body: some View {
        Button(item.copyIDTitle) { model.copyUDID(item) }
        Button(item.copyNameTitle) { model.copyName(item) }
        Button(item.showFolderTitle) { model.showFolder(item) }
        if item.canDelete {
            Divider()
            Button("Delete All Logs of This Simulator…", role: .destructive) { model.deleteAllFiles(of: item) }
        }
    }
}
