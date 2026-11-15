import LogReaderKit
import SwiftUI

struct JSONFieldsSection: View {

    @Bindable var model: EntryInspectorViewModel
    let sheet: TextStyleSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("JSON")
                    .font(sheet.swiftUIFont(for: .title))
                    .foregroundStyle(sheet.color(for: .title))
                Spacer()
                Picker("JSON", selection: $model.showsJSONTree) {
                    Text("Text").tag(false)
                    Text("Tree").tag(true)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            if model.showsJSONTree {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.jsonFields) { field in
                            JSONTreeView(model: model, field: field, sheet: sheet)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .frame(minHeight: 120, idealHeight: 280, maxHeight: 360)
            }
        }
    }
}
