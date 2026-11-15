import Foundation
import LogReaderCore

public extension SourceRule {

    var editorDisplayName: String {
        (editorCommand as NSString).lastPathComponent == "xed" ? "Xcode" : "Editor"
    }

    var openTitle: String {
        "Open in \(editorDisplayName)"
    }
}
