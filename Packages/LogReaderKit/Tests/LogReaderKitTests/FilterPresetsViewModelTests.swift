import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct FilterPresetsViewModelTests {

    private let sourceFactory = FakeLogSourceFactory()
    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let workspace: Workspace
    private let model: FilterPresetsViewModel

    init() async {
        let profiles = await RegistryFixtures.loaded(settings: settings, profile: ProfileFixtures.textTrailing)
        workspace = Workspace(
            sidebar: SidebarStore(discovery: FakeLogDiscovery(devices: []), scanInterval: .seconds(60)),
            sessionFactory: DefaultLogSessionFactory(
                sourceFactory: sourceFactory,
                bookmarkRepository: FakeBookmarkRepository(stored: [:]),
                debounce: .milliseconds(1)
            ),
            settings: settings,
            profiles: profiles
        )
        model = FilterPresetsViewModel(workspace: workspace, settings: settings)
    }

    @Test func itemsHaveSummariesAndShortcutsForTheFirstNine() {
        settings.filterPresets = (1...10).map { preset(name: "P\($0)") }
        var facets = FacetSelection.all
        facets[.level] = .only(["error"])
        settings.filterPresets[0] = preset(name: "Errors", searchText: "socket", facets: facets)
        settings.filterPresets[1] = preset(name: "Find", searchText: "pay", searchMode: .find)

        let items = model.items

        #expect(items.count == 10)
        #expect(items[0].name == "Errors")
        #expect(items[0].summary == "error · Filter: socket")
        #expect(items[1].summary == "Find: pay")
        #expect(items[2].summary == "All entries")
        #expect(items[0].shortcutText == "⌃⌘1")
        #expect(items[0].shortcutNumber == 1)
        #expect(items[8].shortcutText == "⌃⌘9")
        #expect(items[9].shortcutText.isEmpty)
        #expect(items[9].shortcutNumber == nil)
    }

    @Test func summariesUseTheProfileOfTheOpenSession() {
        var facets = FacetSelection.all
        facets[.level] = .only(["error"])
        settings.filterPresets = [preset(name: "Errors", searchText: "socket", facets: facets)]

        openSession()

        #expect(workspace.session?.profile == ProfileFixtures.textTrailing)
        #expect(model.items[0].summary == "ERR · Filter: socket")
    }

    @Test func canSaveCurrentNeedsASessionWithActiveFilters() {
        #expect(model.canSaveCurrent == false)
        #expect(model.hasSession == false)

        openSession()
        #expect(model.hasSession)
        #expect(model.canSaveCurrent == false)

        workspace.session?.setLevels(.only(["error"]))
        #expect(model.canSaveCurrent)
        #expect(model.suggestedName == "ERR")
    }

    @Test func saveCurrentTrimsTheNameAndIgnoresAnEmptyOne() {
        openSession()
        workspace.session?.setLevels(.only(["error"]))

        model.saveCurrent(name: "   ")
        #expect(settings.filterPresets.isEmpty)

        model.saveCurrent(name: "  Errors ")
        #expect(settings.filterPresets.map(\.name) == ["Errors"])
        #expect(settings.filterPresets[0].facets.levels == .only(["error"]))
    }

    @Test func saveWithTheSameNameReplacesThePresetInPlace() {
        openSession()
        settings.filterPresets = [preset(name: "Errors"), preset(name: "Other")]
        workspace.session?.setBookmarksOnly(true)

        model.saveCurrent(name: "Errors")

        #expect(settings.filterPresets.map(\.name) == ["Errors", "Other"])
        #expect(settings.filterPresets[0].bookmarksOnly)
    }

    @Test func namePromptIsPrefilledAndSavesTheDraft() {
        openSession()
        workspace.session?.setLevels(.only(["warning"]))

        model.showNamePrompt()
        #expect(model.isNamePromptPresented)
        #expect(model.draftName == "WRN")
        #expect(model.canSaveDraft)

        model.draftName = "  "
        #expect(model.canSaveDraft == false)

        model.draftName = "Warnings"
        model.saveDraft()
        #expect(model.isNamePromptPresented == false)
        #expect(settings.filterPresets.map(\.name) == ["Warnings"])
    }

    @Test func renameChangesOnlyTheName() {
        let first = preset(name: "A")
        settings.filterPresets = [first, preset(name: "B")]

        model.rename(id: first.id, name: " Renamed ")
        #expect(settings.filterPresets.map(\.name) == ["Renamed", "B"])
        #expect(settings.filterPresets[0].id == first.id)

        model.rename(id: first.id, name: "")
        #expect(settings.filterPresets[0].name == "Renamed")
    }

    @Test func deleteRemovesThePreset() {
        let first = preset(name: "A")
        settings.filterPresets = [first, preset(name: "B")]

        model.delete(id: first.id)

        #expect(settings.filterPresets.map(\.name) == ["B"])
        #expect(model.hasPresets)
    }

    @Test func moveReordersLikeSwiftUI() {
        settings.filterPresets = ["A", "B", "C", "D"].map { preset(name: $0) }

        model.move(fromOffsets: [0], toOffset: 3)
        #expect(settings.filterPresets.map(\.name) == ["B", "C", "A", "D"])

        model.move(fromOffsets: [3], toOffset: 0)
        #expect(settings.filterPresets.map(\.name) == ["D", "B", "C", "A"])

        model.move(fromOffsets: [0, 2], toOffset: 4)
        #expect(settings.filterPresets.map(\.name) == ["B", "A", "D", "C"])

        model.move(fromOffsets: [7], toOffset: 0)
        #expect(settings.filterPresets.map(\.name) == ["B", "A", "D", "C"])
    }

    @Test func applySetsTheSessionState() async {
        openSession()
        var facets = FacetSelection.all
        facets[.attribute("tags")] = .only(["network"])
        let first = preset(name: "Net", searchText: "socket", facets: facets)
        let second = preset(name: "Find", searchText: "pay", searchMode: .find)
        settings.filterPresets = [first, second]

        model.apply(id: first.id)
        #expect(workspace.session?.filterState == LogFilterState(preset: first))

        model.apply(index: 1)
        #expect(workspace.session?.filterState == LogFilterState(preset: second))

        model.apply(index: 5)
        #expect(workspace.session?.filterState == LogFilterState(preset: second))
    }

    @Test func manageFlag() {
        model.showManage()
        #expect(model.isManagePresented)
    }

    private func openSession() {
        workspace.open(URL(fileURLWithPath: "/tmp/log-presets.txt"))
    }

    private func preset(name: String) -> FilterPreset {
        preset(name: name, searchText: "", searchMode: .filter, facets: .all)
    }

    private func preset(name: String, searchText: String, facets: FacetSelection) -> FilterPreset {
        preset(name: name, searchText: searchText, searchMode: .filter, facets: facets)
    }

    private func preset(name: String, searchText: String, searchMode: SearchMode) -> FilterPreset {
        preset(name: name, searchText: searchText, searchMode: searchMode, facets: .all)
    }

    private func preset(name: String, searchText: String, searchMode: SearchMode, facets: FacetSelection) -> FilterPreset {
        FilterPreset(
            id: UUID(),
            name: name,
            searchText: searchText,
            searchMode: searchMode,
            searchScope: .message,
            isRegex: false,
            facets: facets,
            bookmarksOnly: false,
            extraTerms: []
        )
    }
}
