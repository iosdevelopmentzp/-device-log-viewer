import LogReaderKit
import SwiftUI

struct ManagePresetsSheet: View {

    let model: FilterPresetsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter Presets")
                .font(.headline)
            if model.hasPresets {
                List {
                    ForEach(model.items) { item in
                        PresetRow(
                            item: item,
                            onRename: { model.rename(id: item.id, name: $0) },
                            onDelete: { model.delete(id: item.id) }
                        )
                    }
                    .onMove(perform: model.move(fromOffsets:toOffset:))
                }
                .frame(minHeight: 240)
            } else {
                ContentUnavailableView(
                    "No Presets",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Set filters, then choose Save Current Filters as Preset… in the Filters menu.")
                )
                .frame(minHeight: 240)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 460)
    }
}
