import AppKit
import LogReaderKit

final class AppKitAppearanceApplier {
}

// MARK: - AppearanceApplier

extension AppKitAppearanceApplier: AppearanceApplier {

    func apply(_ appearance: Appearance) {
        NSApp.appearance = appearance.nsAppearance
    }
}
