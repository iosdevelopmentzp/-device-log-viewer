import Foundation
import LogReaderCore
import LogReaderKit

final class FakeLogSourceFactory: LogSourceFactory {

    private(set) var sources: [FakeLogSource] = []
    private(set) var profiles: [LogProfile] = []

    func makeSource(for url: URL, profile: LogProfile) -> any LogSource {
        let source = FakeLogSource(url: url)
        sources.append(source)
        profiles.append(profile)
        return source
    }
}
