import LogReaderKit
import SwiftUI

struct FacetFilterView: View {

    @Bindable var model: FacetFilterViewModel

    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.title)
                    .font(.headline)
                Spacer()
                Button("Clear") { model.clear() }
                    .disabled(model.isActive == false)
                    .help("Remove this column filter and show every value")
            }
            .controlSize(.small)

            Picker("", selection: $model.mode) {
                ForEach(model.modeOptions) { option in
                    Text(option.title).tag(option.mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            Text(model.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.showsSearchField {
                TextField(model.searchPrompt, text: $query)
                    .textFieldStyle(.roundedBorder)
            }

            if model.hasValues {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.values(matching: query)) { item in
                            FacetFilterRow(
                                item: item,
                                onToggle: { model.toggle(item) },
                                onOnly: { model.only(item) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 360)
            } else {
                Text("No values in this file yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
