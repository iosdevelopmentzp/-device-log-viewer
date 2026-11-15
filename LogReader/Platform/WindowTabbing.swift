import AppKit

enum WindowTabbing {

    static func enable() {
        NSWindow.allowsAutomaticWindowTabbing = true
    }
}
