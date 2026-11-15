import LogReaderKit
import SwiftUI

struct FileRow: View {

    let item: SidebarFileItem

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(item.title)
                    .lineLimit(1)
                if item.isNewest {
                    Text("latest")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
            }
            HStack(spacing: 6) {
                Text(item.sizeText)
                if item.matchText.isEmpty == false {
                    Text(item.matchText)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .help(item.url.path)
    }
}
