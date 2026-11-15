import LogReaderKit
import SwiftUI

struct SettingsView: View {

    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Show connected devices", isOn: $settings.showsConnectedDevices)
            } header: {
                Text("General")
            } footer: {
                Text("Lists iPhones connected by USB or Wi-Fi. Only apps installed from Xcode show their log files.")
                    .foregroundStyle(.secondary)
            }
            UpdateSettingsSection()
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(settings.appearanceOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
                Slider(value: $settings.fontSize, in: settings.fontSizeRange, step: 1) {
                    Text(settings.fontSizeText)
                }
            }
            Section("Table") {
                Picker("Time zone", selection: $settings.timeZoneMode) {
                    ForEach(settings.timeZoneOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Row density", selection: $settings.rowDensity) {
                    ForEach(settings.rowDensityOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Font", selection: $settings.fontFamily) {
                    ForEach(settings.fontFamilyOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
            Section("Columns") {
                ForEach(settings.columnOptions) { option in
                    Toggle(
                        option.title,
                        isOn: Binding(
                            get: { option.isOn },
                            set: { _ in settings.toggleColumn(option.column) }
                        )
                    )
                    .disabled(option.canHide == false)
                }
            }
            Section("Simulators") {
                Toggle("Open the newest log file automatically", isOn: $settings.followLatestFile)
            }
            Section("Alerts") {
                Toggle("Bounce the Dock icon when an error arrives and the window is in the background", isOn: $settings.alertsOnErrors)
            }
            Section {
                ForEach(settings.projectItems) { item in
                    ProjectRow(
                        item: item,
                        onRemove: { settings.removeProject(id: item.id) },
                        onCreateExample: { settings.createExampleProfile(id: item.id) }
                    )
                }
                HStack {
                    Button("Add Folder…") { settings.addProject() }
                    Button("Reload") { settings.reloadProfiles() }
                }
            } header: {
                Text("Projects")
            } footer: {
                Text(settings.projectsFooter)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
    }
}
