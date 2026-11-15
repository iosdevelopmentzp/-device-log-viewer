import LogReaderKit
import SwiftUI

struct JSONTreeRow: View {

    let item: JSONTreeRowItem
    let sheet: TextStyleSheet
    let onToggle: () -> Void
    let onCopyValue: () -> Void
    let onCopyKeyPath: () -> Void
    let onCopyJSON: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            disclosure
                .frame(width: 12)
            Text(item.key)
                .font(sheet.swiftUIFont(for: .fieldKey))
                .foregroundStyle(sheet.color(for: .fieldKey))
            Text(item.valueText)
                .font(sheet.swiftUIFont(for: item.valueStyle))
                .foregroundStyle(sheet.color(for: item.valueStyle))
                .lineLimit(4)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(item.depth) * 14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard item.isContainer else { return }
            onToggle()
        }
        .contextMenu {
            Button("Copy Value", action: onCopyValue)
            Button("Copy Key Path", action: onCopyKeyPath)
            Button("Copy JSON", action: onCopyJSON)
        }
    }
}

// MARK: - Private

private extension JSONTreeRow {

    @ViewBuilder
    var disclosure: some View {
        if item.isContainer {
            Button(action: onToggle) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(item.isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
        }
    }
}
