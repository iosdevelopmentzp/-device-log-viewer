import LogReaderKit
import SwiftUI

@main
struct LogReaderApp: App {

    @State private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup(id: "main", for: URL.self) { $url in
            MainView(
                model: dependencies.makeMainViewModel(),
                appearanceApplier: dependencies.appearanceApplier,
                initialURL: url
            )
                .environment(dependencies.settingsViewModel)
                .environment(dependencies.updateViewModel)
                .frame(minWidth: 900, minHeight: 500)
        }
        .commands {
            LogCommands(settings: dependencies.settingsViewModel, updates: dependencies.updateViewModel)
        }

        Settings {
            SettingsView()
                .environment(dependencies.settingsViewModel)
        }
    }
}
