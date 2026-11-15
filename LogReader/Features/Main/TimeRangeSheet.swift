import LogReaderKit
import SwiftUI

struct TimeRangeSheet: View {

    @Bindable var model: TimeRangeViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Range")
                .font(.headline)
            Form {
                TextField("Start", text: $model.startText)
                TextField("End", text: $model.endText)
            }
            .onSubmit(apply)
            Text(model.hintText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: LogColors.warningText))
            }
            HStack {
                if model.hasTimeRange {
                    Button("Clear", action: clear)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply", action: apply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.canApply == false)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}

// MARK: - Private

private extension TimeRangeSheet {

    func apply() {
        guard model.apply() else { return }
        dismiss()
    }

    func clear() {
        model.clear()
        dismiss()
    }
}
