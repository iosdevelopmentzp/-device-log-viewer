import LogReaderKit
import SwiftUI

struct SearchHistoryRow: View {

    let item: RecentSearchItem
    let onPin: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(item.text)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            tag(item.modeTitle)
            tag(item.scopeTitle)
            if item.isRegexTitle.isEmpty == false {
                tag(item.isRegexTitle)
            }
            Text(item.timeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            Button(action: onPin) {
                Image(systemName: item.pinSymbolName)
            }
            .buttonStyle(.borderless)
            .opacity(isHovered || item.isPinned ? 1 : 0)
            .help("Pin")
            Button(action: onRemove) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .opacity(isHovered ? 1 : 0)
            .help("Remove from history")
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Private

private extension SearchHistoryRow {

    func tag(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .fixedSize()
    }
}
