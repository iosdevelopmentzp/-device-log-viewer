import LogReaderKit
import SwiftUI

struct JSONTreeView: View {

    let model: EntryInspectorViewModel
    let field: JSONFieldItem
    let sheet: TextStyleSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.key)
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(model.visibleRows(of: field)) { row in
                    JSONTreeRow(
                        item: row,
                        sheet: sheet,
                        onToggle: { model.toggleNode(id: row.id) },
                        onCopyValue: { model.copyValue(nodeID: row.id) },
                        onCopyKeyPath: { model.copyKeyPath(nodeID: row.id) },
                        onCopyJSON: { model.copySubtree(nodeID: row.id) }
                    )
                }
            }
        }
    }
}
