import LogReaderKit
import SwiftUI

struct FilterMenu: View {

    @Bindable var model: FilterMenuViewModel
    let presets: FilterPresetsViewModel
    let onTimeRange: () -> Void

    var body: some View {
        Menu {
            ForEach(presets.items) { item in
                Button(item.name) { presets.apply(id: item.id) }
            }
            Divider()
            Button("Save Current Filters as Preset…") { presets.showNamePrompt() }
                .disabled(presets.canSaveCurrent == false)
            Button("Manage Presets…") { presets.showManage() }
            Divider()
            Section {
                Button("Time Range…", action: onTimeRange)
                Button("Clear Time Range") { model.clearTimeRange() }
                    .disabled(model.hasTimeRange == false)
            }
            Section {
                Button("Clear All Entries") { model.clearAllEntries() }
                Button("Clear Entries Before Selected") { model.clearEntriesBeforeSelection() }
                    .disabled(model.canClearAroundSelection == false)
                Button("Clear Entries After Selected") { model.clearEntriesAfterSelection() }
                    .disabled(model.canClearAroundSelection == false)
                Button("Clear Selected Entries") { model.clearSelectedEntries() }
                    .disabled(model.canClearSelection == false)
                Button("Restore All Entries") { model.restoreAllEntries() }
                    .disabled(model.hasClearedEntries == false)
            }
            Section {
                Menu("Recent Filters") {
                    if model.hasRecentFilters {
                        ForEach(model.recentFilterItems) { item in
                            Button(item.title) { model.applyRecentFilter(id: item.id) }
                        }
                    } else {
                        Button("No recent filters") {}
                            .disabled(true)
                    }
                }
            }
            Section("Levels") {
                ForEach(model.levelOptions) { option in
                    Toggle(option.title, isOn: Binding(get: { option.isOn }, set: { _ in model.toggle(levelID: option.id) }))
                }
                if let title = model.alertLevelsTitle {
                    Button(title) { model.showAlertLevels() }
                }
                if let title = model.highlightedLevelsTitle {
                    Button(title) { model.showHighlightedAndAbove() }
                }
                Button("All Levels") { model.showAllLevels() }
                    .disabled(model.isAllLevels)
            }
            Section {
                Toggle("Bookmarks Only", isOn: $model.bookmarksOnly)
                Button("Clear Filters") { model.clearFilters() }
                    .disabled(model.hasActiveFilters == false)
            }
        } label: {
            Label("Filters", systemImage: model.symbolName)
        }
        .help("Filter by level or bookmarks. Click a column header for more filters.")
    }
}
