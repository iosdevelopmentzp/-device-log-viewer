import SwiftUI

struct GoToEntrySheet: View {

    let prompt: String
    let onGo: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Entry")
                .font(.headline)
            TextField(prompt, text: $text)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Go", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(Int(text) == nil)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - Private

private extension GoToEntrySheet {

    func submit() {
        guard let number = Int(text) else { return }
        onGo(number)
        dismiss()
    }
}
