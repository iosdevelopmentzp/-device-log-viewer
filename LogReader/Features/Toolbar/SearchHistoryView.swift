import LogReaderKit
import SwiftUI

struct SearchHistoryView: View {

    @Bindable var model: SearchHistoryViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField("Filter recent searches", text: $model.filterText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(applySelected)
                .padding(8)
            Divider()
            List(selection: $model.selectedID) {
                ForEach(model.items) { item in
                    SearchHistoryRow(
                        item: item,
                        onPin: { model.togglePin(id: item.id) },
                        onRemove: { model.remove(id: item.id) }
                    )
                    .tag(item.id)
                }
            }
            .listStyle(.plain)
            .contextMenu(forSelectionType: UUID.self) { _ in
                EmptyView()
            } primaryAction: { ids in
                guard let id = ids.first else { return }
                model.apply(id: id)
                onClose()
            }
            .onKeyPress(.return) {
                applySelected()
                return .handled
            }
            .frame(height: 280)
            Divider()
            HStack {
                Spacer()
                Button("Clear History") { model.clear() }
                    .buttonStyle(.link)
                    .help("Remove all entries that are not pinned")
            }
            .padding(8)
        }
        .frame(width: 420)
        .onExitCommand(perform: onClose)
    }
}

// MARK: - Private

private extension SearchHistoryView {

    func applySelected() {
        model.applySelected()
        onClose()
    }
}
