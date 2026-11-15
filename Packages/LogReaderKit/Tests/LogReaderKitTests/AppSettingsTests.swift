import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct AppSettingsTests {

    @Test func emptyStoreGivesDefaults() {
        let settings = AppSettings(store: InMemoryKeyValueStore())

        #expect(settings.fontSize == 12)
        #expect(settings.appearance == .system)
        #expect(settings.timeZoneMode == .local)
        #expect(settings.hiddenColumns.isEmpty)
        #expect(settings.rowDensity == .comfortable)
        #expect(settings.fontFamily == .monospaced)
        #expect(settings.followLatestFile)
        #expect(settings.expandsRows == false)
        #expect(settings.collapsesRepeats == false)
        #expect(settings.searchScope == .message)
        #expect(settings.searchUsesRegex == false)
        #expect(settings.sidebarShowsBootedOnly == false)
        #expect(settings.searchHistory == .empty)
        #expect(settings.filterHistory == .empty)
        #expect(settings.projectRoots.isEmpty)
        #expect(settings.alertsOnErrors)
        #expect(settings.inspectorShowsJSONTree)
        #expect(settings.showsConnectedDevices)
        #expect(settings.connectedDevicesFlag.isOn)
    }

    @Test func valuesRoundTripThroughTheStore() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)

        settings.fontSize = 15
        settings.appearance = .dark
        settings.timeZoneMode = .utc
        settings.hiddenColumns = [.delta, .attribute("tags")]
        settings.rowDensity = .compact
        settings.fontFamily = .system
        settings.followLatestFile = false
        settings.expandsRows = true
        settings.collapsesRepeats = true
        settings.searchScope = SearchScope(ids: ["message", "source"])
        settings.searchUsesRegex = true
        settings.sidebarShowsBootedOnly = true
        settings.projectRoots = ["/tmp/project", "/tmp/other"]
        settings.alertsOnErrors = false
        settings.inspectorShowsJSONTree = false
        settings.showsConnectedDevices = false
        let reloaded = AppSettings(store: store)

        #expect(reloaded.fontSize == 15)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.timeZoneMode == .utc)
        #expect(reloaded.hiddenColumns == [.delta, .attribute("tags")])
        #expect(reloaded.rowDensity == .compact)
        #expect(reloaded.fontFamily == .system)
        #expect(reloaded.followLatestFile == false)
        #expect(reloaded.expandsRows)
        #expect(reloaded.collapsesRepeats)
        #expect(reloaded.searchScope == SearchScope(ids: ["message", "source"]))
        #expect(reloaded.searchUsesRegex)
        #expect(reloaded.sidebarShowsBootedOnly)
        #expect(reloaded.projectRoots == ["/tmp/project", "/tmp/other"])
        #expect(reloaded.alertsOnErrors == false)
        #expect(reloaded.inspectorShowsJSONTree == false)
        #expect(reloaded.showsConnectedDevices == false)
        #expect(reloaded.connectedDevicesFlag.isOn == false)
    }

    @Test func connectedDevicesFlagFollowsTheSetting() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)

        settings.showsConnectedDevices = false
        #expect(settings.connectedDevicesFlag.isOn == false)
        #expect(store.object(forKey: "devices.enabled") as? Bool == false)

        settings.showsConnectedDevices = true
        #expect(settings.connectedDevicesFlag.isOn)
    }

    @Test func keysMatchTheStoredPreferences() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)

        settings.appearance = .light
        settings.fontSize = 10
        settings.sidebarShowsBootedOnly = true
        settings.projectRoots = ["/tmp/project"]
        settings.searchScope = SearchScope(ids: ["tags", "message"])
        settings.searchUsesRegex = true
        settings.collapsesRepeats = true
        settings.alertsOnErrors = false
        settings.inspectorShowsJSONTree = false

        #expect(store.object(forKey: "inspector.jsonTree") as? Bool == false)
        #expect(store.bool(forKey: "table.collapseRepeats"))
        #expect(store.object(forKey: "alerts.errors") as? Bool == false)
        #expect(store.object(forKey: "projects.roots") as? [String] == ["/tmp/project"])
        #expect(store.object(forKey: "settings.searchScopeIDs") as? [String] == ["message", "tags"])
        #expect(store.bool(forKey: "search.regex"))
        #expect(store.string(forKey: "settings.appearance") == "light")
        #expect(store.double(forKey: "settings.fontSize") == 10)
        #expect(store.bool(forKey: "sidebar.bootedOnly"))
    }

    @Test func tableKeysMatchTheStoredPreferences() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)

        settings.hiddenColumns = [.attribute("source"), .delta]
        settings.rowDensity = .compact
        settings.fontFamily = .system

        #expect(store.object(forKey: "table.hiddenColumns") as? [String] == ["delta", "source"])
        #expect(store.string(forKey: "table.density") == "compact")
        #expect(store.string(forKey: "table.fontFamily") == "system")
    }

    @Test func hiddenDeltaColumnMigratesFromTheOldKey() {
        let store = InMemoryKeyValueStore()
        store.set(false, forKey: "settings.showDeltaColumn")

        #expect(AppSettings(store: store).hiddenColumns == [.delta])
    }

    @Test func shownDeltaColumnMigratesToNoHiddenColumns() {
        let store = InMemoryKeyValueStore()
        store.set(true, forKey: "settings.showDeltaColumn")

        #expect(AppSettings(store: store).hiddenColumns.isEmpty)
    }

    @Test func newColumnsKeyWinsOverTheOldDeltaKey() {
        let store = InMemoryKeyValueStore()
        store.set(false, forKey: "settings.showDeltaColumn")
        store.set(["tags"], forKey: "table.hiddenColumns")

        #expect(AppSettings(store: store).hiddenColumns == [.attribute("tags")])
    }

    @Test func unknownTableValuesGiveDefaults() {
        let store = InMemoryKeyValueStore()
        store.set(["tags", "message"], forKey: "table.hiddenColumns")
        store.set("dense", forKey: "table.density")
        store.set("serif", forKey: "table.fontFamily")

        let settings = AppSettings(store: store)

        #expect(settings.hiddenColumns == [.attribute("tags")])
        #expect(settings.rowDensity == .comfortable)
        #expect(settings.fontFamily == .monospaced)
    }

    @Test func fontSizeIsClamped() {
        let settings = AppSettings(store: InMemoryKeyValueStore())

        settings.fontSize = 22
        settings.increaseFontSize()
        #expect(settings.fontSize == 22)

        settings.fontSize = 9
        settings.decreaseFontSize()
        #expect(settings.fontSize == 9)

        settings.resetFontSize()
        #expect(settings.fontSize == AppSettings.defaultFontSize)
    }

    @Test func nextAppearanceCycles() {
        let settings = AppSettings(store: InMemoryKeyValueStore())

        settings.selectNextAppearance()
        #expect(settings.appearance == .light)
        settings.selectNextAppearance()
        #expect(settings.appearance == .dark)
        settings.selectNextAppearance()
        #expect(settings.appearance == .system)
    }

    @Test func historiesRoundTripThroughTheStore() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let search = RecentSearch(id: UUID(), text: "socket", mode: .find, scope: SearchScope(ids: ["message", "tags"]), isRegex: false, date: date, isPinned: true)
        var facets = FacetSelection.all
        facets[.level] = .except(["debug"])
        facets[.attribute("source")] = .only(["Store"])
        let filter = RecentFilterSet(id: UUID(), facets: facets, bookmarksOnly: true, date: date)

        settings.searchHistory = settings.searchHistory.adding(search)
        settings.filterHistory = settings.filterHistory.adding(filter)

        #expect(store.object(forKey: "search.recent") is Data)
        #expect(store.object(forKey: "filters.recent") is Data)
        let reloaded = AppSettings(store: store)
        #expect(reloaded.searchHistory == SearchHistory(entries: [search]))
        #expect(reloaded.filterHistory == FilterHistory(entries: [filter]))
    }

    @Test func corruptHistoryGivesEmptyHistory() {
        let store = InMemoryKeyValueStore()
        store.set(Data("not json".utf8), forKey: "search.recent")
        store.set("wrong type", forKey: "filters.recent")

        let settings = AppSettings(store: store)

        #expect(settings.searchHistory == .empty)
        #expect(settings.filterHistory == .empty)
    }

    @Test func presetsRoundTripThroughTheStore() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)
        #expect(settings.filterPresets.isEmpty)
        var state = LogFilterState(searchScope: SearchScope(ids: ["message", "tags"]), isRegex: false)
        state.searchText = "socket"
        state.facets[.level] = .only(["error"])
        let preset = state.makePreset(name: "Errors")

        settings.filterPresets = [preset]

        #expect(store.object(forKey: "filters.presets") is Data)
        #expect(AppSettings(store: store).filterPresets == [preset])
    }

    @Test func corruptPresetsGiveAnEmptyList() {
        let store = InMemoryKeyValueStore()
        store.set(Data("not json".utf8), forKey: "filters.presets")

        #expect(AppSettings(store: store).filterPresets.isEmpty)
    }

    @Test func legacyProjectRootBecomesTheOnlyProject() {
        let store = InMemoryKeyValueStore()
        store.set("/tmp/example", forKey: "source.projectRoot")

        #expect(AppSettings(store: store).projectRoots == ["/tmp/example"])
    }

    @Test func emptyLegacyProjectRootGivesNoProjects() {
        let store = InMemoryKeyValueStore()
        store.set("", forKey: "source.projectRoot")

        #expect(AppSettings(store: store).projectRoots.isEmpty)
    }

    @Test func projectRootsKeyWinsOverTheLegacyProjectRoot() {
        let store = InMemoryKeyValueStore()
        store.set("/tmp/old", forKey: "source.projectRoot")
        store.set([String](), forKey: "projects.roots")

        #expect(AppSettings(store: store).projectRoots.isEmpty)
    }

    @Test func legacySearchScopeIntegerMigratesByBits() {
        let store = InMemoryKeyValueStore()
        store.set(1 | 2 | 8 | 16, forKey: "settings.searchScope")

        #expect(AppSettings(store: store).searchScope == SearchScope(ids: ["message", "tags", "source", "level"]))
    }

    @Test func legacyCategoryBitMigratesToCategory() {
        let store = InMemoryKeyValueStore()
        store.set(4, forKey: "settings.searchScope")

        #expect(AppSettings(store: store).searchScope == SearchScope(ids: ["category"]))
    }

    @Test func zeroLegacySearchScopeGivesMessage() {
        let store = InMemoryKeyValueStore()
        store.set(0, forKey: "settings.searchScope")

        #expect(AppSettings(store: store).searchScope == .message)
    }

    @Test func searchScopeIDsWinOverTheLegacyInteger() {
        let store = InMemoryKeyValueStore()
        store.set(2, forKey: "settings.searchScope")
        store.set(["subsystem"], forKey: "settings.searchScopeIDs")

        #expect(AppSettings(store: store).searchScope == SearchScope(ids: ["subsystem"]))
    }

    @Test func hiddenColumnsKeepAttributeIDsOfAnyProfile() {
        let store = InMemoryKeyValueStore()
        store.set(["subsystem", "tags", "delta"], forKey: "table.hiddenColumns")

        let settings = AppSettings(store: store)

        #expect(settings.hiddenColumns == [.attribute("subsystem"), .attribute("tags"), .delta])
    }
}
