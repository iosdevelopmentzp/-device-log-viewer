import Foundation
import LogReaderKit

@MainActor
final class FakeSidebarWindowObserver: SidebarWindowObserver {

    private(set) var requestedURLs: [URL] = []

    func sidebar(_ sidebar: SidebarViewModel, requestsNewWindowFor url: URL) {
        requestedURLs.append(url)
    }
}
