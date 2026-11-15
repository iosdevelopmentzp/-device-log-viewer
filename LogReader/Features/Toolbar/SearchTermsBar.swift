import LogReaderKit
import SwiftUI

struct SearchTermsBar: View {

    let model: SearchTermsViewModel

    var body: some View {
        if model.isEmpty == false {
            content
        }
    }
}

// MARK: - Private

private extension SearchTermsBar {

    var content: some View {
        VStack(spacing: 0) {
            ForEach(model.items) { item in
                SearchTermRow(
                    item: item,
                    joinTitle: model.joinTitle,
                    containsTitle: model.containsTitle,
                    excludesTitle: model.excludesTitle,
                    prompt: model.prompt,
                    onSetText: { model.setText(id: item.id, $0) },
                    onSetNegated: { model.setNegated(id: item.id, $0) },
                    onRemove: { model.remove(id: item.id) }
                )
                .padding(.horizontal, 10)
                .frame(height: 28)
            }
            Divider()
        }
        .background(.bar)
    }
}
