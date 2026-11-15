import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class AppSettings {

    private enum Key {
        static let fontSize = "settings.fontSize"
        static let appearance = "settings.appearance"
        static let timeZoneMode = "settings.timeZoneMode"
        static let legacyShowDeltaColumn = "settings.showDeltaColumn"
        static let hiddenColumns = "table.hiddenColumns"
        static let rowDensity = "table.density"
        static let fontFamily = "table.fontFamily"
        static let followLatestFile = "settings.followLatestFile"
        static let expandsRows = "settings.expandsRows"
        static let collapsesRepeats = "table.collapseRepeats"
        static let legacySearchScope = "settings.searchScope"
        static let searchScope = "settings.searchScopeIDs"
        static let searchUsesRegex = "search.regex"
        static let sidebarShowsBootedOnly = "sidebar.bootedOnly"
        static let searchHistory = "search.recent"
        static let filterHistory = "filters.recent"
        static let filterPresets = "filters.presets"
        static let legacyProjectRootPath = "source.projectRoot"
        static let projectRoots = "projects.roots"
        static let alertsOnErrors = "alerts.errors"
        static let inspectorShowsJSONTree = "inspector.jsonTree"
        static let showsConnectedDevices = "devices.enabled"
    }

    public var fontSize: Double {
        didSet { store.set(fontSize, forKey: Key.fontSize) }
    }
    public var appearance: Appearance {
        didSet { store.set(appearance.rawValue, forKey: Key.appearance) }
    }
    public var timeZoneMode: TimeZoneMode {
        didSet { store.set(timeZoneMode.rawValue, forKey: Key.timeZoneMode) }
    }
    public var hiddenColumns: Set<LogTableColumn> {
        didSet { store.set(hiddenColumns.map(\.rawValue).sorted(), forKey: Key.hiddenColumns) }
    }
    public var rowDensity: RowDensity {
        didSet { store.set(rowDensity.rawValue, forKey: Key.rowDensity) }
    }
    public var fontFamily: FontFamily {
        didSet { store.set(fontFamily.rawValue, forKey: Key.fontFamily) }
    }
    public var followLatestFile: Bool {
        didSet { store.set(followLatestFile, forKey: Key.followLatestFile) }
    }
    public var expandsRows: Bool {
        didSet { store.set(expandsRows, forKey: Key.expandsRows) }
    }
    public var collapsesRepeats: Bool {
        didSet { store.set(collapsesRepeats, forKey: Key.collapsesRepeats) }
    }
    public var searchScope: SearchScope {
        didSet { store.set(searchScope.ids.sorted(), forKey: Key.searchScope) }
    }
    public var searchUsesRegex: Bool {
        didSet { store.set(searchUsesRegex, forKey: Key.searchUsesRegex) }
    }
    public var sidebarShowsBootedOnly: Bool {
        didSet { store.set(sidebarShowsBootedOnly, forKey: Key.sidebarShowsBootedOnly) }
    }
    public var searchHistory: SearchHistory {
        didSet { store.set(Self.encode(searchHistory), forKey: Key.searchHistory) }
    }
    public var filterHistory: FilterHistory {
        didSet { store.set(Self.encode(filterHistory), forKey: Key.filterHistory) }
    }
    public var filterPresets: [FilterPreset] {
        didSet { store.set(Self.encode(filterPresets), forKey: Key.filterPresets) }
    }
    public var projectRoots: [String] {
        didSet { store.set(projectRoots, forKey: Key.projectRoots) }
    }
    public var alertsOnErrors: Bool {
        didSet { store.set(alertsOnErrors, forKey: Key.alertsOnErrors) }
    }
    public var inspectorShowsJSONTree: Bool {
        didSet { store.set(inspectorShowsJSONTree, forKey: Key.inspectorShowsJSONTree) }
    }
    public var showsConnectedDevices: Bool {
        didSet {
            store.set(showsConnectedDevices, forKey: Key.showsConnectedDevices)
            connectedDevicesFlag.set(showsConnectedDevices)
        }
    }

    public let connectedDevicesFlag: SharedFlag

    @ObservationIgnored private let store: any KeyValueStore

    public static let fontSizeRange: ClosedRange<Double> = 9...22
    public static let defaultFontSize: Double = 12
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(store: any KeyValueStore) {
        self.store = store
        let storedFontSize = store.double(forKey: Key.fontSize)
        self.fontSize = storedFontSize == 0 ? Self.defaultFontSize : storedFontSize
        self.appearance = store.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        self.timeZoneMode = store.string(forKey: Key.timeZoneMode).flatMap(TimeZoneMode.init(rawValue:)) ?? .local
        self.hiddenColumns = Self.loadHiddenColumns(from: store)
        self.rowDensity = store.string(forKey: Key.rowDensity).flatMap(RowDensity.init(rawValue:)) ?? .comfortable
        self.fontFamily = store.string(forKey: Key.fontFamily).flatMap(FontFamily.init(rawValue:)) ?? .monospaced
        self.followLatestFile = store.object(forKey: Key.followLatestFile) as? Bool ?? true
        self.expandsRows = store.bool(forKey: Key.expandsRows)
        self.collapsesRepeats = store.bool(forKey: Key.collapsesRepeats)
        self.searchScope = Self.loadSearchScope(from: store)
        self.searchUsesRegex = store.bool(forKey: Key.searchUsesRegex)
        self.sidebarShowsBootedOnly = store.bool(forKey: Key.sidebarShowsBootedOnly)
        self.searchHistory = Self.decode(SearchHistory.self, from: store.object(forKey: Key.searchHistory)) ?? .empty
        self.filterHistory = Self.decode(FilterHistory.self, from: store.object(forKey: Key.filterHistory)) ?? .empty
        self.filterPresets = Self.decode([FilterPreset].self, from: store.object(forKey: Key.filterPresets)) ?? []
        self.projectRoots = Self.loadProjectRoots(from: store)
        self.alertsOnErrors = store.object(forKey: Key.alertsOnErrors) as? Bool ?? true
        self.inspectorShowsJSONTree = store.object(forKey: Key.inspectorShowsJSONTree) as? Bool ?? true
        let showsConnectedDevices = store.object(forKey: Key.showsConnectedDevices) as? Bool ?? true
        self.showsConnectedDevices = showsConnectedDevices
        self.connectedDevicesFlag = SharedFlag(isOn: showsConnectedDevices)
    }

    public func selectNextAppearance() {
        let all = Appearance.allCases
        let index = all.firstIndex(of: appearance) ?? 0
        appearance = all[(index + 1) % all.count]
    }

    public func increaseFontSize() {
        fontSize = min(fontSize + 1, Self.fontSizeRange.upperBound)
    }

    public func decreaseFontSize() {
        fontSize = max(fontSize - 1, Self.fontSizeRange.lowerBound)
    }

    public func resetFontSize() {
        fontSize = Self.defaultFontSize
    }
}

// MARK: - Private

private extension AppSettings {

    static func loadHiddenColumns(from store: any KeyValueStore) -> Set<LogTableColumn> {
        guard let rawValues = store.object(forKey: Key.hiddenColumns) as? [String] else {
            let showsDelta = store.object(forKey: Key.legacyShowDeltaColumn) as? Bool ?? true
            return showsDelta ? [] : [.delta]
        }
        return Set(rawValues.compactMap(LogTableColumn.init(rawValue:)).filter(\.canHide))
    }

    static func loadSearchScope(from store: any KeyValueStore) -> SearchScope {
        if let ids = store.object(forKey: Key.searchScope) as? [String], ids.isEmpty == false {
            return SearchScope(ids: Set(ids))
        }
        return SearchScope(legacyRawValue: store.integer(forKey: Key.legacySearchScope)) ?? .message
    }

    static func loadProjectRoots(from store: any KeyValueStore) -> [String] {
        if let roots = store.object(forKey: Key.projectRoots) as? [String] {
            return roots
        }
        guard let legacy = store.string(forKey: Key.legacyProjectRootPath), legacy.isEmpty == false else { return [] }
        return [legacy]
    }

    static func encode(_ value: some Encodable) -> Data? {
        try? encoder.encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from object: Any?) -> Value? {
        guard let data = object as? Data else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
