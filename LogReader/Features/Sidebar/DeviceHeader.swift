import LogReaderKit
import SwiftUI

struct DeviceHeader: View {

    let item: SidebarDeviceItem

    var body: some View {
        HStack(spacing: 6) {
            if let symbolName = item.symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(item.isBooted ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
            Text(item.name)
            Text(item.subtitle)
                .foregroundStyle(.tertiary)
        }
        .help(item.id)
    }
}
