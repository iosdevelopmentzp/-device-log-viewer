import Foundation
import LogReaderCore
@testable import LogReaderKit

@MainActor
enum RegistryFixtures {

    static let projectPath = "/tmp/project"
    static let projectRoot = URL(fileURLWithPath: projectPath, isDirectory: true)
    static let modifiedAt = Date(timeIntervalSince1970: 1_800_000_000)

    static func empty(settings: AppSettings) -> ProfileRegistry {
        ProfileRegistry(settings: settings, loader: FakeLogProfileLoader(), reloadInterval: .seconds(60))
    }

    static func loaded(settings: AppSettings, profile: LogProfile) async -> ProfileRegistry {
        let loader = FakeLogProfileLoader()
        loader.setResult(.loaded(profile, modifiedAt: modifiedAt), for: projectRoot)
        settings.projectRoots = [projectPath]
        let registry = ProfileRegistry(settings: settings, loader: loader, reloadInterval: .seconds(60))
        registry.start()
        await Eventually.wait { registry.profiles.isEmpty == false }
        registry.stop()
        return registry
    }
}
