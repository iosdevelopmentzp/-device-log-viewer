import LogReaderKit
import SwiftUI

struct FilterChip: View {

    let item: FilterChipItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(item.title)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Remove this filter")
        }
        .font(.callout)
        .foregroundStyle(foreground)
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 2)
        .background(background, in: Capsule())
    }
}

// MARK: - Private

private extension FilterChip {

    var foreground: Color {
        item.isExclusion ? Color(nsColor: LogColors.chipExclusion) : .primary
    }

    var background: Color {
        item.isExclusion ? Color(nsColor: LogColors.chipExclusion).opacity(0.15) : Color(nsColor: LogColors.chipBackground)
    }
}
