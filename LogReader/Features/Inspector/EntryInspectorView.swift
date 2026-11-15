import LogReaderKit
import SwiftUI

struct EntryInspectorView: View {

    let model: EntryInspectorViewModel
    let searchFocusRequest: Int

    @Environment(SettingsViewModel.self) private var settings
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        content
            .background(Color(nsColor: LogColors.background))
            .onChange(of: searchFocusRequest) {
                isSearchFocused = true
            }
            .task(id: model.loadKey) {
                await model.load()
            }
    }
}

// MARK: - Private

private extension EntryInspectorView {

    var sheet: TextStyleSheet {
        TextStyleSheet(fontSize: settings.fontSize, wrapsByCharacter: false, fontFamily: settings.fontFamily)
    }

    @ViewBuilder
    var content: some View {
        if model.hasSelection == false {
            ContentUnavailableView("No Selection", systemImage: "text.alignleft", description: Text("Select an entry to see the full text."))
        } else if model.isLoading == false, let header = model.header, let layout = model.layout {
            VStack(alignment: .leading, spacing: 0) {
                EntryHeaderView(
                    item: header,
                    copyItems: model.copyItems,
                    onCopy: model.copyEntry,
                    onOpenSource: model.openSource
                )
                .padding(10)
                EntrySearchBar(model: model, isFocused: $isSearchFocused)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                Divider()
                EntryTextView(
                    text: NSAttributedString(layout.text, sheet: sheet),
                    links: layout.links,
                    focusRange: model.focusRange,
                    onDoubleClickWord: { model.highlight(word: $0) },
                    onSearchInLog: { model.searchInLog(text: $0) },
                    searchInLogTitle: { model.searchInLogTitle(for: $0) }
                )
                if model.jsonFields.isEmpty == false && model.showsTreeSection {
                    Divider()
                    JSONFieldsSection(model: model, sheet: sheet)
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
