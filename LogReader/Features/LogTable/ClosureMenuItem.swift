import AppKit

final class ClosureMenuItem: NSMenuItem {

    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

// MARK: - Private

private extension ClosureMenuItem {

    @objc func runHandler() {
        handler()
    }
}
