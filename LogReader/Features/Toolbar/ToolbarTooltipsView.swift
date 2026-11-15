import AppKit

final class ToolbarTooltipsView: NSView {

    var tips: [String: String] = [:] {
        didSet { scheduleApply() }
    }

    private var observer: (any NSObjectProtocol)?

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSToolbar.willAddItemNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, notification.object as? NSToolbar === window?.toolbar else { return }
            scheduleApply()
        }
        scheduleApply()
    }
}

// MARK: - Private

private extension ToolbarTooltipsView {

    func scheduleApply() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            apply()
        }
    }

    func apply() {
        for item in window?.toolbar?.items ?? [] {
            guard let tip = tips[item.label] else { continue }
            item.toolTip = tip
        }
    }
}
