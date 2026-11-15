import Foundation

public final class FileManagerSourceFileIndex {

    private var cache: (root: String, preferredExtension: String, index: [String: [URL]])?

    private static let skippedDirectories: Set<String> = [".build", "DerivedData", "Pods", "node_modules", "Carthage", "build"]

    public init() {}
}

// MARK: - SourceFileIndex

extension FileManagerSourceFileIndex: SourceFileIndex {

    public func locate(fileName: String, under root: URL, preferredExtension: String) -> [URL] {
        let index = index(for: root, preferredExtension: preferredExtension)
        return index[Self.key(for: fileName)] ?? []
    }
}

// MARK: - Private

private extension FileManagerSourceFileIndex {

    func index(for root: URL, preferredExtension: String) -> [String: [URL]] {
        let rootPath = root.standardizedFileURL.path
        if let cache, cache.root == rootPath, cache.preferredExtension == preferredExtension {
            return cache.index
        }
        let index = Self.buildIndex(under: root).mapValues { Self.sorted($0, preferredExtension: preferredExtension) }
        cache = (root: rootPath, preferredExtension: preferredExtension, index: index)
        return index
    }

    static func buildIndex(under root: URL) -> [String: [URL]] {
        var index: [String: [URL]] = [:]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return index }
        for case let url as URL in enumerator {
            if skippedDirectories.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            index[key(for: url.lastPathComponent), default: []].append(url)
        }
        return index
    }

    static func key(for fileName: String) -> String {
        (fileName as NSString).deletingPathExtension.lowercased()
    }

    static func sorted(_ urls: [URL], preferredExtension: String) -> [URL] {
        urls.sorted { lhs, rhs in
            let lhsIsPreferred = lhs.pathExtension == preferredExtension
            let rhsIsPreferred = rhs.pathExtension == preferredExtension
            if lhsIsPreferred != rhsIsPreferred {
                return lhsIsPreferred
            }
            if lhs.path.count != rhs.path.count {
                return lhs.path.count < rhs.path.count
            }
            return lhs.path < rhs.path
        }
    }
}
