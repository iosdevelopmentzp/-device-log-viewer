import LogReaderKit
import SwiftUI

struct PresetRow: View {

    let item: FilterPresetItem
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var name: String

    init(item: FilterPresetItem, onRename: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onRename = onRename
        self.onDelete = onDelete
        _name = State(initialValue: item.name)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .onSubmit { onRename(name) }
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.shortcutText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this preset")
        }
        .padding(.vertical, 2)
        .onChange(of: item.name) {
            name = item.name
        }
    }
}
