import AppKit
import LogReaderKit

@MainActor
final class AppKitAppAttention {

    weak var observer: (any AppAttentionObserver)?

    private var activationToken: (any NSObjectProtocol)?

    init() {
        activationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                observer?.appDidBecomeActive()
            }
        }
    }

    isolated deinit {
        guard let activationToken else { return }
        NotificationCenter.default.removeObserver(activationToken)
    }
}

// MARK: - AppAttention

extension AppKitAppAttention: AppAttention {

    var isAppActive: Bool { NSApp.isActive }

    func requestAttention() {
        NSApp.requestUserAttention(.informationalRequest)
    }

    func setBadge(_ text: String?) {
        NSApp.dockTile.badgeLabel = text
    }
}
