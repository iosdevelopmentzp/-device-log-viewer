import Foundation

@MainActor
public enum ContextMenuEntry {
    case item(ContextMenuItem)
    case separator
}
