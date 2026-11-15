import LogReaderKit
import SwiftUI

struct PresetNameSheet: View {

    @Bindable var model: FilterPresetsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Filters as Preset")
                .font(.headline)
            TextField("Preset name", text: $model.draftName)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.canSaveDraft == false)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}

// MARK: - Private

private extension PresetNameSheet {

    func save() {
        guard model.canSaveDraft else { return }
        model.saveDraft()
    }
}
