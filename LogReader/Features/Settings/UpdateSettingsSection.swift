import LogReaderKit
import SwiftUI

struct UpdateSettingsSection: View {

    @Environment(UpdateViewModel.self) private var model

    var body: some View {
        Section {
            LabeledContent("Installed build", value: model.installedText)
            LabeledContent("Status", value: model.statusText)
            HStack {
                Button("Check Now", action: model.checkNow)
                    .disabled(model.canCheck == false)
                Button("Update Now", action: model.updateNow)
                    .disabled(model.canUpdate == false)
            }
        } header: {
            Text("Updates")
        } footer: {
            Text(model.settingsFooter)
                .foregroundStyle(.secondary)
        }
    }
}
