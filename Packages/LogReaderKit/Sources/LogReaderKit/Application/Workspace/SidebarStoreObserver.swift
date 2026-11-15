import Foundation

@MainActor
public protocol SidebarStoreObserver: AnyObject {
    func devicesDidChange()
}
