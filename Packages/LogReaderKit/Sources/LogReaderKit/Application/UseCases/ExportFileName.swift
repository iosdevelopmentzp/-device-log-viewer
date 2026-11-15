import Foundation

public enum ExportFileName {

    private static let suffix = "-filtered"

    public static func suggested(for url: URL, format: ExportFormat) -> String {
        let base = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ":", with: "-")
        return base + suffix + "." + format.fileExtension
    }
}
