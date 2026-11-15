import LogReaderKit
import SwiftUI

struct EntryHeaderView: View {

    let item: EntryHeaderItem
    let copyItems: [ContextMenuItem]
    let onCopy: () -> Void
    let onOpenSource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let style = item.levelStyle {
                    Text(item.levelTitle)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(Color(nsColor: LevelColors.text(for: style)))
                        .background(Color(nsColor: LevelColors.text(for: style)).opacity(0.15), in: Capsule())
                }
                Text(item.numberText)
                    .foregroundStyle(.secondary)
                if item.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.tint)
                        .help("Bookmarked (⌘B removes the bookmark)")
                }
                Spacer()
                Menu {
                    ForEach(Array(copyItems.enumerated()), id: \.offset) { _, copyItem in
                        Button(copyItem.title, action: copyItem.action)
                            .disabled(copyItem.isEnabled == false)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                } primaryAction: {
                    onCopy()
                }
                .menuStyle(.button)
                .fixedSize()
                .help("Copy the entry. Click the arrow for Copy Message, Copy Source and more.")
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                ForEach(item.metadata) { row in
                    GridRow {
                        Text(row.title)
                            .foregroundStyle(.secondary)
                        if item.hasSource && row.isSource {
                            Button(row.value, action: onOpenSource)
                                .buttonStyle(.link)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(item.openSourceTitle)
                        } else {
                            Text(row.value)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .font(.callout)
        }
    }
}
