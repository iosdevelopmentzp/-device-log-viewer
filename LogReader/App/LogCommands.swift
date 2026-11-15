import LogReaderKit
import SwiftUI

struct LogCommands: Commands {

    let settings: SettingsViewModel
    let updates: UpdateViewModel

    @FocusedValue(\.mainViewModel) private var model

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { updates.checkNow() }
                .disabled(updates.canCheck == false)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Window") { model?.openInNewWindow(nil) }
                .keyboardShortcut("n")
                .disabled(model == nil)
            Button("Open…") { model?.openFile() }
                .keyboardShortcut("o")
        }

        CommandGroup(after: .pasteboard) {
            Button("Copy All Visible Entries") { model?.copyVisible() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model?.hasSession != true)
            Button("Export Visible Entries as Log…") { export(.log) }
                .disabled(model?.canExport != true)
            Button("Export Visible Entries as JSON…") { export(.json) }
                .disabled(model?.canExport != true)
        }

        CommandMenu("Log") {
            Button("Search") { model?.requestSearchFocus() }
                .keyboardShortcut("f")
            Button("Find in Entry") { model?.requestInspectorSearchFocus() }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(model?.canFindInEntry != true)
            Button("Find Next") { model?.findNext() }
                .keyboardShortcut("g")
                .disabled(model?.canFindNext != true)
            Button("Find Previous") { model?.findPrevious() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(model?.canFindNext != true)

            Divider()

            Button("Jump to End") { model?.jumpToEnd() }
                .keyboardShortcut("l")
            Button("Go to Entry…") { model?.showGoToEntry() }
                .keyboardShortcut("j")

            Divider()

            Button("Toggle Bookmark") { model?.toggleBookmark() }
                .keyboardShortcut("b")
            Button("Next Bookmark") { model?.nextBookmark() }
                .keyboardShortcut("]")
            Button("Previous Bookmark") { model?.previousBookmark() }
                .keyboardShortcut("[")
            Button("Show Bookmarks Only") { model?.toggleBookmarksOnly() }
                .keyboardShortcut("b", modifiers: [.command, .option])
            Button("Clear All Bookmarks") { model?.clearBookmarks() }
                .disabled(model?.hasBookmarks != true)

            Divider()

            Button("Clear Filters") { model?.clearFilters() }
                .keyboardShortcut("k")
            Button("Time Range…") { model?.showTimeRange() }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .disabled(model?.hasSession != true)
            Menu("Presets") {
                ForEach(model?.presets.items ?? []) { item in
                    Button(item.name) { model?.presets.apply(id: item.id) }
                        .keyboardShortcut(item.shortcutNumber.map(Self.presetShortcut(number:)))
                        .disabled(model?.hasSession != true)
                }
                Divider()
                Button("Save Current Filters as Preset…") { model?.showSavePreset() }
                    .disabled(model?.presets.canSaveCurrent != true)
                Button("Manage Presets…") { model?.showManagePresets() }
                    .disabled(model?.hasSession != true)
            }

            Divider()

            Button("Clear All Entries") { model?.clearAllEntries() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(model?.hasSession != true)
            Button("Clear Entries Before Selected") { model?.clearEntriesBeforeSelection() }
                .disabled(model?.canClearAroundSelection != true)
            Button("Clear Entries After Selected") { model?.clearEntriesAfterSelection() }
                .disabled(model?.canClearAroundSelection != true)
            Button("Clear Selected Entries") { model?.clearSelectedEntries() }
                .disabled(model?.canClearSelection != true)
            Button("Restore All Entries") { model?.restoreAllEntries() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(model?.hasClearedEntries != true)

            Divider()

            Button("Toggle Inspector") { model?.toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Button(model?.openSourceTitle ?? "Open Source") { model?.openSourceOfSelection() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model?.canOpenSource != true)
        }

        CommandGroup(after: .toolbar) {
            Button(settings.expandRowsTitle) { settings.toggleExpandRows() }
                .keyboardShortcut("e")
            Button(settings.collapseRepeatsTitle) { settings.toggleCollapsesRepeats() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Next Theme") { settings.selectNextAppearance() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Increase Font Size") { settings.increaseFontSize() }
                .keyboardShortcut("+")
            Button("Decrease Font Size") { settings.decreaseFontSize() }
                .keyboardShortcut("-")
            Button("Actual Font Size") { settings.resetFontSize() }
                .keyboardShortcut("0")
            Divider()
            Menu("Columns") {
                ForEach(settings.columnOptions) { option in
                    Toggle(
                        option.title,
                        isOn: Binding(
                            get: { option.isOn },
                            set: { _ in settings.toggleColumn(option.column) }
                        )
                    )
                    .disabled(option.canHide == false)
                }
            }
            Menu("Row Density") {
                Picker("Row Density", selection: rowDensity) {
                    ForEach(settings.rowDensityOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Menu("Font") {
                Picker("Font", selection: fontFamily) {
                    ForEach(settings.fontFamilyOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Divider()
        }
    }
}

// MARK: - Private

private extension LogCommands {

    var rowDensity: Binding<RowDensity> {
        Binding(get: { settings.rowDensity }, set: { settings.rowDensity = $0 })
    }

    var fontFamily: Binding<FontFamily> {
        Binding(get: { settings.fontFamily }, set: { settings.fontFamily = $0 })
    }

    func export(_ format: ExportFormat) {
        guard let model else { return }
        Task { await model.exportVisible(format: format) }
    }

    nonisolated static func presetShortcut(number: Int) -> KeyboardShortcut {
        KeyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: [.control, .command])
    }
}
