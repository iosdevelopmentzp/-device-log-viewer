import Foundation

@MainActor
public protocol SidebarWindowObserver: AnyObject {
    func sidebar(_ sidebar: SidebarViewModel, requestsNewWindowFor url: URL)
}
