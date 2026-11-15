import LogReaderKit
import SwiftUI

struct ThemeMenu: View {

    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Picker("Theme", selection: $settings.appearance) {
                ForEach(settings.appearanceOptions, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Theme", systemImage: settings.appearanceSymbolName)
        }
        .help("Theme: System, Light or Dark (⌘⇧T)")
    }
}
