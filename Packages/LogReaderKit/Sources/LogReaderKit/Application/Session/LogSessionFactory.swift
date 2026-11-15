import Foundation
import LogReaderCore

@MainActor
public protocol LogSessionFactory {
    func makeSession(url: URL, profile: LogProfile, searchScope: SearchScope, isRegex: Bool) -> LogSession
}

@MainActor
public struct DefaultLogSessionFactory: LogSessionFactory {

    private let sourceFactory: any LogSourceFactory
    private let bookmarkRepository: any BookmarkRepository
    private let debounce: Duration

    public init(sourceFactory: any LogSourceFactory, bookmarkRepository: any BookmarkRepository, debounce: Duration) {
        self.sourceFactory = sourceFactory
        self.bookmarkRepository = bookmarkRepository
        self.debounce = debounce
    }

    public func makeSession(url: URL, profile: LogProfile, searchScope: SearchScope, isRegex: Bool) -> LogSession {
        LogSession(
            url: url,
            profile: profile,
            source: sourceFactory.makeSource(for: url, profile: profile),
            bookmarkRepository: bookmarkRepository,
            filterRunner: LogFilterRunner(debounce: debounce),
            searchScope: searchScope,
            isRegex: isRegex
        )
    }
}
