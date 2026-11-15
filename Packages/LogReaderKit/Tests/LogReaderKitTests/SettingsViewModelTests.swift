import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct SettingsViewModelTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let dialogs = FakeFileDialogs()
    private let loader = FakeLogProfileLoader()
    private let profiles: ProfileRegistry

    init() {
        profiles = ProfileRegistry(settings: settings, loader: loader, reloadInterval: .seconds(60))
    }

    @Test func propertiesReadAndWriteTheSettings() {
        let model = makeModel()

        model.fontSize = 15
        model.appearance = .dark
        model.timeZoneMode = .utc
        model.rowDensity = .compact
        model.fontFamily = .system
        model.followLatestFile = false
        model.sidebarShowsBootedOnly = true
        model.alertsOnErrors = false
        model.inspectorShowsJSONTree = false
        model.showsConnectedDevices = false

        #expect(settings.fontSize == 15)
        #expect(settings.appearance == .dark)
        #expect(settings.timeZoneMode == .utc)
        #expect(settings.rowDensity == .compact)
        #expect(model.rowDensity == .compact)
        #expect(settings.fontFamily == .system)
        #expect(model.fontFamily == .system)
        #expect(settings.followLatestFile == false)
        #expect(settings.sidebarShowsBootedOnly)
        #expect(settings.alertsOnErrors == false)
        #expect(model.alertsOnErrors == false)
        #expect(settings.inspectorShowsJSONTree == false)
        #expect(model.inspectorShowsJSONTree == false)
        #expect(settings.showsConnectedDevices == false)
        #expect(model.showsConnectedDevices == false)
        #expect(model.fontSizeText == "Font size: 15")
        #expect(model.appearanceSymbolName == "moon")
    }

    @Test func toggleColumnHidesAndShowsTheColumn() {
        let model = makeModel()
        #expect(model.isColumnShown(.delta))

        model.toggleColumn(.delta)
        #expect(settings.hiddenColumns == [.delta])
        #expect(model.hiddenColumns == [.delta])
        #expect(model.isColumnShown(.delta) == false)

        model.toggleColumn(.delta)
        #expect(settings.hiddenColumns.isEmpty)
        #expect(model.isColumnShown(.delta))
    }

    @Test func messageColumnCannotBeHidden() {
        let model = makeModel()

        model.toggleColumn(.message)

        #expect(settings.hiddenColumns.isEmpty)
        #expect(model.isColumnShown(.message))
    }

    @Test func columnOptionsFollowTheHiddenColumns() {
        let model = makeModel()
        settings.hiddenColumns = [.attribute("subsystem")]

        let options = model.columnOptions

        #expect(options.map(\.column) == LogTableColumn.all(in: ProfileRegistry.builtIn))
        #expect(options.map(\.title) == ["#", "Time", "Δ", "Level", "Subsystem", "Category", "Source", "Process", "Thread", "Message"])
        #expect(options.filter { $0.isOn == false }.map(\.column) == [.attribute("subsystem")])
        #expect(options.filter { $0.canHide == false }.map(\.column) == [.message])
        #expect(model.rowDensityOptions == [.compact, .comfortable])
        #expect(model.fontFamilyOptions == [.monospaced, .system])
    }

    @Test func expandRowsTextsFollowTheSetting() {
        let model = makeModel()

        #expect(model.expandRowsTitle == "Expand Rows")
        #expect(model.expandRowsSymbolName == "arrow.up.left.and.arrow.down.right")
        #expect(model.expandRowsHelp == "Show the full text of every entry (⌘E)")

        model.toggleExpandRows()

        #expect(settings.expandsRows)
        #expect(model.expandRowsTitle == "Collapse Rows")
        #expect(model.expandRowsSymbolName == "arrow.down.right.and.arrow.up.left")
        #expect(model.expandRowsHelp == "Show one line per entry (⌘E)")
    }

    @Test func collapseRepeatsTextsFollowTheSetting() {
        let model = makeModel()

        #expect(model.collapsesRepeats == false)
        #expect(model.collapseRepeatsTitle == "Collapse Repeated Entries")
        #expect(model.collapseRepeatsSymbolName == "rectangle.compress.vertical")
        #expect(model.collapseRepeatsHelp == "Show consecutive entries with the same message and level as one row (⌘⇧R)")

        model.toggleCollapsesRepeats()

        #expect(settings.collapsesRepeats)
        #expect(model.collapseRepeatsTitle == "Expand Repeated Entries")
        #expect(model.collapseRepeatsSymbolName == "rectangle.expand.vertical")
        #expect(model.collapseRepeatsHelp == "Show every repeated entry in its own row (⌘⇧R)")

        model.collapsesRepeats = false
        #expect(settings.collapsesRepeats == false)
    }

    @Test func actionsForwardToTheSettings() {
        let model = makeModel()

        model.increaseFontSize()
        #expect(settings.fontSize == AppSettings.defaultFontSize + 1)
        model.decreaseFontSize()
        model.decreaseFontSize()
        #expect(settings.fontSize == AppSettings.defaultFontSize - 1)
        model.resetFontSize()
        #expect(settings.fontSize == AppSettings.defaultFontSize)
        model.selectNextAppearance()
        #expect(settings.appearance == .light)
        #expect(model.appearanceOptions == Appearance.allCases)
        #expect(model.timeZoneOptions == TimeZoneMode.allCases)
        #expect(model.fontSizeRange == AppSettings.fontSizeRange)
    }

    @Test func columnOptionsAddTheColumnsOfLoadedProfiles() async {
        let model = makeModel()
        await loadProject(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt))

        let titles = model.columnOptions.map(\.title)

        #expect(titles == ["#", "Time", "Δ", "Level", "Subsystem", "Category", "Source", "Process", "Thread", "Message", "Tags"])
    }

    @Test func addProjectUsesTheChosenFolder() async {
        let model = makeModel()
        #expect(model.hasProjects == false)

        model.addProject()
        #expect(settings.projectRoots.isEmpty)

        loader.setResult(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt), for: RegistryFixtures.projectRoot)
        dialogs.folderToChoose = RegistryFixtures.projectRoot
        model.addProject()
        await Eventually.wait { model.hasProjects }
        profiles.stop()

        #expect(settings.projectRoots == [RegistryFixtures.projectPath])
        #expect(model.projectItems == [
            ProjectItem(
                id: RegistryFixtures.projectPath,
                name: "Example App",
                pathText: RegistryFixtures.projectPath,
                statusText: "Profile loaded. Simulators and devices: bundle IDs starting with com.example.",
                hasError: false,
                canCreateExample: false
            )
        ])
    }

    @Test func removeProjectDropsIt() async {
        let model = makeModel()
        await loadProject(.loaded(ProfileFixtures.textTrailing, modifiedAt: RegistryFixtures.modifiedAt))
        profiles.start()

        model.removeProject(id: RegistryFixtures.projectPath)
        await Eventually.wait { model.hasProjects == false }
        profiles.stop()

        #expect(settings.projectRoots.isEmpty)
    }

    @Test func projectWithoutProfileCanCreateTheExample() async {
        let model = makeModel()
        await loadProject(.missing)

        let item = model.projectItems.first
        #expect(item?.name == "project")
        #expect(item?.statusText == "No profile. Files are read as JSON Lines.")
        #expect(item?.canCreateExample == true)
        #expect(item?.hasError == false)

        model.createExampleProfile(id: RegistryFixtures.projectPath)
        profiles.stop()

        #expect(loader.writtenRoots == [RegistryFixtures.projectRoot])
        #expect(dialogs.presentedErrors.isEmpty)
    }

    @Test func failedExampleIsPresented() async {
        struct WriteError: Error {}
        let model = makeModel()
        await loadProject(.missing)
        loader.setError(WriteError())

        model.createExampleProfile(id: RegistryFixtures.projectPath)

        #expect(dialogs.presentedErrors.count == 1)
        #expect(loader.writtenRoots.isEmpty)
    }

    @Test func projectWithAnInvalidProfileShowsTheError() async {
        let model = makeModel()
        await loadProject(.failed("Missing key “entry” at the top level.", modifiedAt: RegistryFixtures.modifiedAt))

        let item = model.projectItems.first
        #expect(item?.statusText == "Profile error: Missing key “entry” at the top level.")
        #expect(item?.hasError == true)
        #expect(item?.canCreateExample == false)
    }

    @Test func profileWithoutDiscoveryOpensFilesOnlyByHand() async {
        var profile = ProfileFixtures.textTrailing
        profile.discovery = nil
        let model = makeModel()
        await loadProject(.loaded(profile, modifiedAt: RegistryFixtures.modifiedAt))

        #expect(model.projectItems.first?.statusText == "Profile loaded. No discovery rule, so files open only by hand.")
    }

    @Test func reloadLoadsTheProfilesAgain() async {
        let model = makeModel()
        await loadProject(.missing)
        let loads = loader.loadedRoots.count

        model.reloadProfiles()
        await Eventually.wait { loader.loadedRoots.count > loads }
        profiles.stop()

        #expect(model.projectsFooter.contains(".logreader/profile.json"))
    }

    private func makeModel() -> SettingsViewModel {
        SettingsViewModel(settings: settings, fileDialogs: dialogs, profiles: profiles)
    }

    private func loadProject(_ result: ProfileLoadResult) async {
        loader.setResult(result, for: RegistryFixtures.projectRoot)
        settings.projectRoots = [RegistryFixtures.projectPath]
        profiles.start()
        await Eventually.wait { profiles.projects.isEmpty == false }
        profiles.stop()
    }
}
