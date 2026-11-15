import Foundation

public enum LogFileTitle {

    public static func title(for url: URL, prefix: String) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        guard prefix.isEmpty == false, name.hasPrefix(prefix), name.count > prefix.count else { return url.lastPathComponent }
        return String(name.dropFirst(prefix.count))
    }
}
