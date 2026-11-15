import AppKit
import LogReaderKit

enum LogRowMenuBuilder {

    static func build(_ entries: [ContextMenuEntry], into menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case .item(let item):
                let menuItem = ClosureMenuItem(title: item.title, handler: item.action)
                menuItem.isEnabled = item.isEnabled
                menu.addItem(menuItem)
            }
        }
    }
}
