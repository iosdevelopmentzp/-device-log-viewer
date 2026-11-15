import AppKit
import LogReaderKit

final class SystemPasteboard {
}

// MARK: - Pasteboard

extension SystemPasteboard: LogReaderKit.Pasteboard {

    func write(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func write(fileURL: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([fileURL as NSURL])
    }
}
