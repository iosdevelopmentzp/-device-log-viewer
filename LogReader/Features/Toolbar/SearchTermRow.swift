import LogReaderKit
import SwiftUI

struct SearchTermRow: View {

    let item: SearchTermItem
    let joinTitle: String
    let containsTitle: String
    let excludesTitle: String
    let prompt: String
    let onSetText: (String) -> Void
    let onSetNegated: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(joinTitle)
                .foregroundStyle(.secondary)
            Picker(containsTitle, selection: negatedBinding) {
                Text(containsTitle).tag(false)
                Text(excludesTitle).tag(true)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            TextField(prompt, text: textBinding, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this condition")
        }
        .font(.callout)
    }
}

// MARK: - Private

private extension SearchTermRow {

    var negatedBinding: Binding<Bool> {
        Binding(get: { item.isNegated }, set: onSetNegated)
    }

    var textBinding: Binding<String> {
        Binding(get: { item.text }, set: onSetText)
    }
}
