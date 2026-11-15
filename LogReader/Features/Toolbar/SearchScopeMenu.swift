import LogReaderKit
import SwiftUI

struct SearchScopeMenu: View {

    let model: SearchViewModel

    var body: some View {
        Menu {
            Section("Search in") {
                ForEach(model.scopeOptions) { option in
                    Toggle(option.title, isOn: Binding(get: { option.isOn }, set: { _ in model.toggleScope(id: option.id) }))
                }
            }
            Section {
                Button("Message Only") { model.useMessageScope() }
                Button("All Columns") { model.useAllScopes() }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "magnifyingglass")
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(model.isScopeDefault ? Color.secondary : Color.accentColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(model.scopeSummary)
    }
}
