import LogReaderKit
import SwiftUI

struct ProjectRow: View {

    let item: ProjectItem
    let onRemove: () -> Void
    let onCreateExample: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(item.pathText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.statusText)
                    .font(.caption)
                    .foregroundStyle(item.hasError ? Color.red : Color.secondary)
            }
            Spacer()
            if item.canCreateExample {
                Button("Create Example Profile", action: onCreateExample)
            }
            Button("Remove", action: onRemove)
        }
    }
}
