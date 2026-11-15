import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SettingsViewModel {

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let fileDialogs: any FileDialogs
    @ObservationIgnored private let profiles: ProfileRegistry

    public var fontSize: Double {
        get { settings.fontSize }
        set { settings.fontSize = newValue }
    }

    public var appearance: Appearance {
        get { settings.appearance }
        set { settings.appearance = newValue }
    }

    public var timeZoneMode: TimeZoneMode {
        get { settings.timeZoneMode }
        set { settings.timeZoneMode = newValue }
    }

    public var hiddenColumns: Set<LogTableColumn> { settings.hiddenColumns }

    public var rowDensity: RowDensity {
        get { settings.rowDensity }
        set { settings.rowDensity = newValue }
    }

    public var fontFamily: FontFamily {
        get { settings.fontFamily }
        set { settings.fontFamily = newValue }
    }

    public var followLatestFile: Bool {
        get { settings.followLatestFile }
        set { settings.followLatestFile = newValue }
    }

    public var expandsRows: Bool {
        get { settings.expandsRows }
        set { settings.expandsRows = newValue }
    }

    public var collapsesRepeats: Bool {
        get { settings.collapsesRepeats }
        set { settings.collapsesRepeats = newValue }
    }

    public var sidebarShowsBootedOnly: Bool {
        get { settings.sidebarShowsBootedOnly }
        set { settings.sidebarShowsBootedOnly = newValue }
    }

    public var alertsOnErrors: Bool {
        get { settings.alertsOnErrors }
        set { settings.alertsOnErrors = newValue }
    }

    public var inspectorShowsJSONTree: Bool {
        get { settings.inspectorShowsJSONTree }
        set { settings.inspectorShowsJSONTree = newValue }
    }

    public var showsConnectedDevices: Bool {
        get { settings.showsConnectedDevices }
        set { settings.showsConnectedDevices = newValue }
    }

    public var projectItems: [ProjectItem] {
        profiles.projects.map { project in
            ProjectItem(
                id: project.id,
                name: project.name,
                pathText: (project.root.path as NSString).abbreviatingWithTildeInPath,
                statusText: Self.statusText(of: project),
                hasError: project.errorText != nil,
                canCreateExample: project.hasProfile == false && project.errorText == nil
            )
        }
    }

    public var hasProjects: Bool { profiles.projects.isEmpty == false }

    public var projectsFooter: String {
        "Each project folder holds \(ProjectProfile.profileFolder)/\(ProjectProfile.profileFileName), which describes its log files. "
            + "Files without a matching profile are read as JSON lines (\(ProfileRegistry.builtIn.name))."
    }

    public var appearanceOptions: [Appearance] { Appearance.allCases }

    public var timeZoneOptions: [TimeZoneMode] { TimeZoneMode.allCases }

    public var rowDensityOptions: [RowDensity] { RowDensity.allCases }

    public var fontFamilyOptions: [FontFamily] { FontFamily.allCases }

    public var columnOptions: [ColumnOption] {
        var seen = Set<LogTableColumn>()
        var options: [ColumnOption] = []
        for profile in [ProfileRegistry.builtIn] + profiles.profiles {
            for column in LogTableColumn.all(in: profile) where seen.insert(column).inserted {
                options.append(ColumnOption(
                    column: column,
                    title: column.displayName(in: profile),
                    isOn: isColumnShown(column),
                    canHide: column.canHide
                ))
            }
        }
        return options
    }

    public var fontSizeRange: ClosedRange<Double> { AppSettings.fontSizeRange }

    public var fontSizeText: String { "Font size: \(Int(settings.fontSize))" }

    public var appearanceSymbolName: String { settings.appearance.symbolName }

    public var expandRowsTitle: String {
        settings.expandsRows ? "Collapse Rows" : "Expand Rows"
    }

    public var expandRowsSymbolName: String {
        settings.expandsRows ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
    }

    public var expandRowsHelp: String {
        settings.expandsRows ? "Show one line per entry (⌘E)" : "Show the full text of every entry (⌘E)"
    }

    public var collapseRepeatsTitle: String {
        settings.collapsesRepeats ? "Expand Repeated Entries" : "Collapse Repeated Entries"
    }

    public var collapseRepeatsSymbolName: String {
        settings.collapsesRepeats ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
    }

    public var collapseRepeatsHelp: String {
        settings.collapsesRepeats
            ? "Show every repeated entry in its own row (⌘⇧R)"
            : "Show consecutive entries with the same message and level as one row (⌘⇧R)"
    }

    public init(settings: AppSettings, fileDialogs: any FileDialogs, profiles: ProfileRegistry) {
        self.settings = settings
        self.fileDialogs = fileDialogs
        self.profiles = profiles
    }

    public func selectNextAppearance() {
        settings.selectNextAppearance()
    }

    public func increaseFontSize() {
        settings.increaseFontSize()
    }

    public func decreaseFontSize() {
        settings.decreaseFontSize()
    }

    public func resetFontSize() {
        settings.resetFontSize()
    }

    public func isColumnShown(_ column: LogTableColumn) -> Bool {
        settings.hiddenColumns.contains(column) == false
    }

    public func toggleColumn(_ column: LogTableColumn) {
        guard column.canHide else { return }
        if settings.hiddenColumns.contains(column) {
            settings.hiddenColumns.remove(column)
        } else {
            settings.hiddenColumns.insert(column)
        }
    }

    public func toggleExpandRows() {
        settings.expandsRows.toggle()
    }

    public func toggleCollapsesRepeats() {
        settings.collapsesRepeats.toggle()
    }

    public func addProject() {
        guard let url = fileDialogs.chooseFolder() else { return }
        profiles.addProject(url)
    }

    public func removeProject(id: String) {
        profiles.removeProject(id: id)
    }

    public func reloadProfiles() {
        profiles.reload()
    }

    public func createExampleProfile(id: String) {
        do {
            try profiles.createExampleProfile(id: id)
        } catch {
            fileDialogs.present(error)
        }
    }
}

// MARK: - Private

private extension SettingsViewModel {

    static func statusText(of project: ProjectProfile) -> String {
        if let errorText = project.errorText {
            return "Profile error: \(errorText)"
        }
        guard let profile = project.profile else {
            return "No profile. Files are read as \(ProfileRegistry.builtIn.name)."
        }
        guard let discovery = profile.discovery else {
            return "Profile loaded. No discovery rule, so files open only by hand."
        }
        let prefix = discovery.bundleIDPrefix.isEmpty ? "every app" : "bundle IDs starting with \(discovery.bundleIDPrefix)"
        return "Profile loaded. Simulators and devices: \(prefix)."
    }
}
