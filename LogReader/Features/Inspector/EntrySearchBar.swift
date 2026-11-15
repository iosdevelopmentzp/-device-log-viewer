import LogReaderKit
import SwiftUI

struct EntrySearchBar: View {

    @Bindable var model: EntryInspectorViewModel
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find in this entry (⌥⌘F)", text: $model.entrySearchText)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onSubmit(model.nextMatch)
            if model.showsMatchControls {
                Text(model.matchCountText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Button(action: model.previousMatch) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(model.canNavigateMatches == false)
                .help("Previous match in this entry")
                Button(action: model.nextMatch) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(model.canNavigateMatches == false)
                .help("Next match in this entry (Return)")
                Button(action: model.clearEntrySearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear the entry search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: LogColors.background), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isFocused.wrappedValue ? Color(nsColor: LogColors.localMatch) : Color.secondary.opacity(0.3))
        }
    }
}
