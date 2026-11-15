import LogReaderKit
import SwiftUI

struct SearchBar: View {

    @Bindable var model: SearchViewModel
    var isFocused: FocusState<Bool>.Binding

    @State private var isHistoryPresented = false

    var body: some View {
        HStack(spacing: 8) {
            Picker("Search Mode", selection: $model.mode) {
                ForEach(model.modeOptions) { Text($0.title).tag($0.mode) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Filter hides entries without a match. Find keeps every entry and highlights matches.")

            HStack(spacing: 6) {
                Button(action: model.addCondition) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(model.canAddCondition == false)
                .help("Add a condition")
                Button {
                    isHistoryPresented.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.borderless)
                .disabled(model.hasHistory == false)
                .help("Recent searches")
                .popover(isPresented: $isHistoryPresented, arrowEdge: .bottom) {
                    SearchHistoryView(model: model.historyViewModel) {
                        isHistoryPresented = false
                    }
                }
                SearchScopeMenu(model: model)
                TextField(model.prompt, text: $model.text)
                    .textFieldStyle(.plain)
                    .focused(isFocused)
                    .onSubmit {
                        model.commitSearch()
                        model.submit()
                    }
                    .onChange(of: isFocused.wrappedValue) { _, isFocused in
                        guard isFocused == false else { return }
                        model.commitSearch()
                    }
                if model.showsFindControls {
                    Text(model.positionText)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Button(action: model.findPrevious) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.canNavigate == false)
                    .help("Previous match (⇧⌘G)")
                    Button(action: model.findNext) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.canNavigate == false)
                    .help("Next match (⌘G or Return)")
                }
                Button {
                    model.isRegex.toggle()
                } label: {
                    Text(".*")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(model.isRegex ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Treat the search as a regular expression")
                if model.showsClearButton {
                    Button(action: model.clear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: 340)
            .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(borderColor)
            }
            .help(model.fieldHelp)
        }
    }
}

// MARK: - Private

private extension SearchBar {

    var borderColor: Color {
        guard model.isTextValid else { return Color(nsColor: LogColors.warningText) }
        return isFocused.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.3)
    }
}
