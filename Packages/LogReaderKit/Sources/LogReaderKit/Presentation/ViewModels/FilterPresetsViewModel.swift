import Foundation
import Observation

@MainActor
@Observable
public final class FilterPresetsViewModel {

    public var isManagePresented = false
    public var isNamePromptPresented = false
    public var draftName = ""

    @ObservationIgnored private let workspace: Workspace
    @ObservationIgnored private let settings: AppSettings

    public var items: [FilterPresetItem] {
        let profile = workspace.session?.profile ?? ProfileRegistry.builtIn
        return settings.filterPresets.enumerated().map { index, preset in
            let shortcutNumber = index < Self.shortcutCount ? index + 1 : nil
            return FilterPresetItem(
                id: preset.id,
                name: preset.name,
                summary: FilterPresetSummary.text(of: LogFilterState(preset: preset), profile: profile),
                shortcutNumber: shortcutNumber,
                shortcutText: shortcutNumber.map { "⌃⌘\($0)" } ?? ""
            )
        }
    }

    public var hasPresets: Bool { settings.filterPresets.isEmpty == false }

    public var hasSession: Bool { workspace.session != nil }

    public var canSaveCurrent: Bool { workspace.session?.filterState.hasPresetContent == true }

    public var canSaveDraft: Bool { Self.trimmed(draftName).isEmpty == false }

    public var suggestedName: String {
        workspace.session.map { FilterPresetSummary.text(of: $0.filterState, profile: $0.profile) } ?? ""
    }

    private static let shortcutCount = 9

    public init(workspace: Workspace, settings: AppSettings) {
        self.workspace = workspace
        self.settings = settings
    }

    public func showNamePrompt() {
        guard canSaveCurrent else { return }
        draftName = suggestedName
        isNamePromptPresented = true
    }

    public func showManage() {
        isManagePresented = true
    }

    public func saveDraft() {
        saveCurrent(name: draftName)
        isNamePromptPresented = false
    }

    public func apply(id: UUID) {
        guard let preset = settings.filterPresets.first(where: { $0.id == id }) else { return }
        workspace.session?.apply(preset)
    }

    public func apply(index: Int) {
        guard settings.filterPresets.indices.contains(index) else { return }
        apply(id: settings.filterPresets[index].id)
    }

    public func saveCurrent(name: String) {
        let name = Self.trimmed(name)
        guard name.isEmpty == false, let session = workspace.session else { return }
        let preset = session.filterState.makePreset(name: name)
        guard let index = settings.filterPresets.firstIndex(where: { $0.name == name }) else {
            settings.filterPresets.append(preset)
            return
        }
        settings.filterPresets[index] = preset
    }

    public func rename(id: UUID, name: String) {
        let name = Self.trimmed(name)
        guard name.isEmpty == false, let index = settings.filterPresets.firstIndex(where: { $0.id == id }) else { return }
        guard settings.filterPresets[index].name != name else { return }
        settings.filterPresets[index].name = name
    }

    public func delete(id: UUID) {
        settings.filterPresets.removeAll { $0.id == id }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let presets = settings.filterPresets
        guard source.allSatisfy(presets.indices.contains), (0...presets.count).contains(destination) else { return }
        let moving = source.map { presets[$0] }
        var remaining = presets.enumerated().filter { source.contains($0.offset) == false }.map(\.element)
        let insertion = destination - source.count(where: { $0 < destination })
        remaining.insert(contentsOf: moving, at: insertion)
        settings.filterPresets = remaining
    }
}

// MARK: - Private

private extension FilterPresetsViewModel {

    static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
