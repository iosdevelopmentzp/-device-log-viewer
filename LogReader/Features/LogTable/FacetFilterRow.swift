import LogReaderKit
import SwiftUI

struct FacetFilterRow: View {

    let item: FacetValueItem
    let onToggle: () -> Void
    let onOnly: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Toggle(isOn: Binding(get: { item.isSelected }, set: { _ in onToggle() })) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 4)
            if isHovered {
                Button(item.actionTitle, action: onOnly)
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .help(item.actionHelp)
            }
            Text(item.countText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
