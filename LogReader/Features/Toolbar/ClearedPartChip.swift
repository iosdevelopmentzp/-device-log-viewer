import LogReaderKit
import SwiftUI

struct ClearedPartChip: View {

    let item: ClearedPartItem
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(item.title)
                .lineLimit(1)
            Button(action: onRestore) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Restore these entries")
        }
        .font(.callout)
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: LogColors.chipBackground), in: Capsule())
    }
}
