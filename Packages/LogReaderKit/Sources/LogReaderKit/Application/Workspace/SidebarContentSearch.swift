import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SidebarContentSearch {

    private struct CacheKey: Equatable {
        let text: String
        let isRegex: Bool
    }

    private struct CachedResult {
        let size: Int64
        let result: FileSearchResult
    }

    public private(set) var isSearching = false
    public private(set) var results: [String: FileSearchResult]?

    @ObservationIgnored private let searcher: any FileContentSearcher
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let sizeLimit: Int
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var cacheKey: CacheKey?
    @ObservationIgnored private var cache: [String: CachedResult] = [:]

    public init(searcher: any FileContentSearcher, debounce: Duration, sizeLimit: Int) {
        self.searcher = searcher
        self.debounce = debounce
        self.sizeLimit = sizeLimit
    }

    public func update(query: String, isRegex: Bool, files: [SearchableFile]) {
        stop()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            results = nil
            cache = [:]
            cacheKey = nil
            return
        }
        let key = CacheKey(text: text, isRegex: isRegex)
        if key != cacheKey {
            cache = [:]
            cacheKey = key
        }
        isSearching = true
        let token = generation
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounce)
            guard Task.isCancelled == false else { return }
            await search(text: text, isRegex: isRegex, files: files, token: token)
        }
    }

    public func stop() {
        searchTask?.cancel()
        searchTask = nil
        generation += 1
        isSearching = false
    }
}

// MARK: - Private

private extension SidebarContentSearch {

    func search(text: String, isRegex: Bool, files: [SearchableFile], token: Int) async {
        guard let query = Self.query(text: text, isRegex: isRegex) else {
            finish(with: [:], token: token)
            return
        }
        let pending = files.filter { cache[$0.url.path]?.size != $0.size }
        guard pending.isEmpty == false else {
            finish(with: cachedResults(for: files), token: token)
            return
        }
        let searcher = searcher
        let sizeLimit = sizeLimit
        let work = Task.detached(priority: .utility) {
            Self.countMatches(of: query, in: pending, searcher: searcher, sizeLimit: sizeLimit)
        }
        let found = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        guard Task.isCancelled == false, token == generation, let found else { return }
        for file in pending {
            guard let result = found[file.url.path] else { continue }
            cache[file.url.path] = CachedResult(size: file.size, result: result)
        }
        finish(with: cachedResults(for: files), token: token)
    }

    func cachedResults(for files: [SearchableFile]) -> [String: FileSearchResult] {
        var found: [String: FileSearchResult] = [:]
        for file in files {
            guard let cached = cache[file.url.path] else { continue }
            found[file.url.path] = cached.result
        }
        return found
    }

    func finish(with found: [String: FileSearchResult], token: Int) {
        guard token == generation else { return }
        results = found
        isSearching = false
    }

    static func query(text: String, isRegex: Bool) -> TextQuery? {
        guard isRegex else { return TextQuery(text) }
        return try? TextQuery.regex(text)
    }

    nonisolated static func countMatches(
        of query: TextQuery,
        in files: [SearchableFile],
        searcher: any FileContentSearcher,
        sizeLimit: Int
    ) -> [String: FileSearchResult]? {
        var found: [String: FileSearchResult] = [:]
        for file in files {
            guard Task.isCancelled == false else { return nil }
            found[file.url.path] = (try? searcher.countMatches(of: query, in: file.url, sizeLimit: sizeLimit)) ?? .count(0)
        }
        return found
    }
}
