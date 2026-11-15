import LogReaderKit

@MainActor
final class FakeSidebarStoreObserver: SidebarStoreObserver {

    private(set) var changeCount = 0

    func devicesDidChange() {
        changeCount += 1
    }
}
