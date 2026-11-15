# Refactoring plan: three layers, one type per file

Status: done on 2026-10-10 (phases 1 to 5). The sections below are the specification that was implemented; section 9 lists where the code differs from it. Decisions: `docs/adr/0004-layered-architecture.md`, `docs/adr/0005-dependency-injection.md`. Rules: `.claude/rules/`.

This document is the specification for the refactoring. Each phase ends with a green build and green tests. A phase does not start before the previous one is done.

## 1. Findings in the MVP

| # | Problem | Where |
|---|---|---|
| 1 | One class owns tailing, content, facet counts, filter state, search, find navigation, bookmarks, selection, follow mode, clipboard and table events. | `Store/LogDocument.swift` (538 lines) |
| 2 | AppKit in the store layer: `NSPasteboard`, `NSOpenPanel`, `NSSavePanel`, `NSAlert`, `NSWorkspace`, `NSApp.appearance`. | `LogDocument`, `Workspace`, `FileActions`, `AppSettings` |
| 3 | Views depend on whole stores. `FacetFilterView`, `FilterMenu`, `SearchBar`, `StatusBar`, `EntryInspectorView`, `LogRowMenuBuilder`, `GoToEntrySheet` each take `LogDocument` and call many methods. | `Features/*` |
| 4 | The table and the inspector depend on `AppSettings.TimeZoneMode`, a settings type. | `LogCellFormatter`, `LogTableView` |
| 5 | Display strings live in model enums (`Appearance.title`, `TimeZoneMode.title`, `SearchMode.title`) and in views (`SearchScopeMenu.title(for:)`). | `Settings/AppSettings.swift`, `Features/Main/MainView.swift` |
| 6 | Facet logic is a four-way `switch` repeated six times (`facetValues`, `isFacetActive`, `isSelected`, `toggleSelection`, `showOnly`, `showAll`). | `LogDocument` |
| 7 | No injection. Stores build `BookmarkStore(defaults: .standard)`, `SimulatorLogScanner`, `LogDocument` inline. Settings reach `Workspace` through an optional set in `start()`. The search scope is persisted through a closure. | `Workspace`, `SidebarModel` |
| 8 | `EntryDetailsContent` is a view that loads, parses and renders in `.task`. It holds a cache and a state machine. | `Features/Inspector/EntryInspectorView.swift` |
| 9 | `LogTableCoordinator` (370 lines) mixes delegate, data source, cell configuration, row height cache, header titles, popover, selection sync, scrolling and follow detection. | `Features/LogTable/LogTableView.swift` |
| 10 | Several types per file: `MainView.swift` (4 views), `LogTableComponents.swift` (3 classes), `SidebarContextMenus.swift` (3 menus), `SidebarView.swift` (3 views), `SimulatorLogScanner.swift` (4 types), `LogRowMenuBuilder.swift`, `LogIndexer.swift`, `LogHeaderLineParser.swift`, `FacetColumn.swift`, `StatusBar.swift`. | everywhere |
| 11 | `LogLevel(code:)` is declared in the app, not in the core. | `Store/FacetColumn.swift` |
| 12 | Two clipboard helpers (`FileActions.copyText`, `LogDocument.writeToPasteboard`). | |
| 13 | No tests for anything outside the core package. | |

What is good and stays: the byte-based core, the `LogFileTailer`, the `NSTableView` decision, the filter engine, the incremental append path, the member order and style rules.

## 2. Target structure

```
Packages/LogReaderCore/Sources/LogReaderCore/
  Domain/        LogLevel, LogRecord, LogBatch, LogFileFormat, FacetColumn
  Parsing/       ByteScan, LogIndexer, LogRecordBuilder, LogHeaderLine, LogHeaderLineParser,
                 LogEntryDetails, LogTextMetrics
  Storage/       LogContent
  Tailing/       LogSource, LogSourceEvent, LogFileTailer
  Filtering/     LogFilter, LogFilterEngine, FacetFilter, FacetSelection, FacetCounts,
                 SearchScope, TextQuery
  Discovery/     SimulatorLogScanner, SimulatorDevice, AppLogContainer, LogFileItem
  Support/       SortedIndices

Packages/LogReaderKit/Sources/LogReaderKit/
  Application/
    Ports/       KeyValueStore, BookmarkRepository, Pasteboard, FileRevealer, FileDialogs,
                 FileCopier, AppearanceApplier, LogDiscovery, LogSourceFactory
    Settings/    AppSettings, Appearance, TimeZoneMode
    Session/     LogSession, LogSessionStatus, LogSessionFactory, LogFilterState, SearchMode,
                 FilterRequest, FilterResult, LogFilterRunner, LogRowsEvent, LogRowsObserver
    Workspace/   Workspace, WorkspaceObserver, SidebarStore, SidebarStoreObserver, NewestFilePolicy
    UseCases/    CopyEntries, FileActions
  Infrastructure/
                 UserDefaults+KeyValueStore, UserDefaultsBookmarkRepository,
                 FileTailerSourceFactory, SimulatorLogDiscovery, FileManagerCopier
  Presentation/
    Models/      TextStyle, StyledText, LogRowItem, EntryHeaderItem, EntryTextLayout,
                 SidebarDeviceItem, SidebarAppItem, SidebarFileItem, FacetValueItem,
                 LevelOption, SearchScopeOption, SearchModeOption, StatusBarItem,
                 ContextMenuItem, ContextMenuEntry
    Formatting/  TimeTextFormatter, DeltaTextFormatter, FileSizeText, LogFileTitle,
                 MessageTextBuilder, EntryTextLayoutBuilder, StatusBarItemBuilder
    Display/     Appearance+Display, TimeZoneMode+Display, SearchMode+Display,
                 SearchScope+Display, FacetColumn+Display
    ViewModels/  MainViewModel, SessionViewModels, SidebarViewModel, SettingsViewModel,
                 LogTablePresenter, LogTableUpdateReceiver, SearchViewModel, FilterMenuViewModel,
                 FacetFilterViewModel, EntryInspectorViewModel, RowContextMenuModel
Packages/LogReaderKit/Tests/LogReaderKitTests/
  Fakes/         FakePasteboard, FakeFileRevealer, FakeFileDialogs, FakeFileCopier,
                 FakeAppearanceApplier, InMemoryKeyValueStore, FakeBookmarkRepository,
                 FakeLogSource, FakeLogSourceFactory, FakeLogDiscovery, LogFixtures
  ...Tests.swift (one file per type under test)

LogReader/
  App/           LogReaderApp, LogCommands, FocusedValues+MainViewModel, AppDependencies
  Platform/      SystemPasteboard, WorkspaceFileRevealer, AppKitFileDialogs,
                 AppKitAppearanceApplier, Appearance+NSAppearance
  Theme/         LogColors, LogFonts, LevelColors, TextStyleSheet, StyledText+NSAttributedString
  Features/
    Main/        MainView, StatusBar, StatusLabelStyle, GoToEntrySheet, ThemeMenu
    Toolbar/     SearchBar, SearchScopeMenu, FilterMenu
    Sidebar/     SidebarView, DeviceHeader, FileRow, LogFileContextMenu,
                 AppContainerContextMenu, DeviceContextMenu
    LogTable/    LogTableView, LogTableCoordinator, LogTableRowHeightCache, LogCellConfigurator,
                 LogNSTableView, LogRowView, LogCellView, LogColumn, LogColumn+FacetColumn,
                 LogRowMenuBuilder, ClosureMenuItem, FacetFilterView, FacetFilterRow
    Inspector/   EntryInspectorView, EntryHeaderView, EntrySearchBar, EntryTextView
    Settings/    SettingsView
Scripts/
  check-layers.sh, check-layers-allow.txt
```

Removed: `LogReader/Store/`, `LogReader/Settings/AppSettings.swift`, `Features/LogTable/LogCellFormatter.swift`, `Features/Inspector/EntryTextRenderer.swift`, `Features/LogTable/LogTableComponents.swift`, `Features/Sidebar/SidebarContextMenus.swift`.

## 3. Phase 1: core package

Goal: one type per file, domain helpers that the kit needs, a `LogSource` protocol. `swift test` and the performance test stay green.

### 3.1 Files

- Move `LogBatch` to `Domain/LogBatch.swift`.
- Move `LogHeaderLine` to `Parsing/LogHeaderLine.swift`.
- Move `LogRecord.isStructured` into `Domain/LogRecord.swift`.
- Split `Discovery/SimulatorLogScanner.swift` into `SimulatorDevice.swift`, `AppLogContainer.swift`, `LogFileItem.swift`, `SimulatorLogScanner.swift`.
- `LogFileTailer.Event` becomes `Tailing/LogSourceEvent.swift`. `FileIdentity` stays nested (private helper of the tailer).

### 3.2 New types

`Domain/FacetColumn.swift`

```swift
public enum FacetColumn: CaseIterable, Sendable, Hashable {
    case level, tags, category, source

    public func values(of record: LogRecord) -> [String]
    // level → [level.code], tags → tags, category → [category], source → [sourceFile]; nil → []
}
```

`Domain/LogLevel.swift`: add `public init?(code: String)` (moved from the app).

`Filtering/FacetCounts.swift`

```swift
public struct FacetCounts: Sendable, Equatable {
    public struct Entry: Sendable, Hashable, Identifiable {
        public let value: String
        public let count: Int
        public var id: String { value }
    }
    public init()
    public mutating func add(_ records: ArraySlice<LogRecord>)
    public mutating func removeAll()
    public func count(of value: String, in column: FacetColumn) -> Int
    public func entries(in column: FacetColumn) -> [Entry]
}
```

`entries(in: .level)` returns every `LogLevel` code in level order, with count 0 when absent. Other columns: sorted by count descending, then `localizedStandardCompare`.

`Filtering/FacetSelection.swift`

```swift
public struct FacetSelection: Sendable, Equatable {
    public var levels: FacetFilter<LogLevel>
    public var tags: FacetFilter<String>
    public var categories: FacetFilter<String>
    public var sources: FacetFilter<String>

    public static let all: FacetSelection
    public var isAll: Bool
    public func isActive(_ column: FacetColumn) -> Bool
    public func isSelected(_ value: String, in column: FacetColumn) -> Bool
    public mutating func toggle(_ value: String, in column: FacetColumn)
    public mutating func showOnly(_ values: Set<String>, in column: FacetColumn)   // empty set → showAll
    public mutating func showAll(in column: FacetColumn)
}
```

One private `subscript(column: FacetColumn) -> FacetFilter<String>` with get and set does the level code conversion. No other `switch` over the column in this type.

`LogFilter` changes to `text`, `scope`, `facets: FacetSelection`, `onlyOffsets`. `LogFilterEngine.matches` reads `filter.facets.levels` and so on. Update the tests.

`Support/SortedIndices.swift`

```swift
public enum SortedIndices {
    public static func lowerBound(of value: Int, in sorted: [Int]) -> Int      // first index with element >= value, or count
    public static func position(of value: Int, in sorted: [Int]) -> Int?      // exact match only
    public static func nearestPosition(of value: Int, in sorted: [Int]) -> Int?  // lowerBound clamped to the last index; nil when empty
    public static func next(after value: Int, in sorted: [Int]) -> Int?       // wraps to the first element
    public static func previous(before value: Int, in sorted: [Int]) -> Int?  // wraps to the last element
}
```

`Tailing/LogSource.swift`, `Tailing/LogSourceEvent.swift`

```swift
public enum LogSourceEvent: Sendable {
    case batch(LogBatch)
    case reset
    case missing
}

public protocol LogSource: AnyObject, Sendable {
    var url: URL { get }
    func events() -> AsyncStream<LogSourceEvent>
    func stop()
}
```

`LogFileTailer` conforms in `// MARK: - LogSource` extension inside `LogFileTailer.swift`.

### 3.3 Tests

New: `FacetCountsTests`, `FacetSelectionTests`, `SortedIndicesTests`, `FacetColumnTests`. Update `LogFileTailerTests` and `LogFilterEngineTests`. Run `LOGREADER_PERF=1 swift test -c release --filter PerformanceTests` and keep the numbers in `docs/architecture.md` current.

## 4. Phase 2: kit package, application layer

Goal: `Packages/LogReaderKit` exists, is linked into the app, and holds the application layer with tests. The app still builds with its old code (it does not import the kit yet).

### 4.1 Package

`Packages/LogReaderKit/Package.swift`: `swift-tools-version: 6.0`, `platforms: [.macOS(.v15)]`, product `LogReaderKit`, dependency `.package(path: "../LogReaderCore")`, test target `LogReaderKitTests`. Explicit `@MainActor` on every observable class; no default isolation setting.

`LogReader.xcodeproj/project.pbxproj`: add the package the same way `LogReaderCore` is added. Four edits, one new id prefix (for example `3BD1D8C2...`, `3BD1D8C3...`, `3BD1D8C4...`):

1. `XCLocalSwiftPackageReference "Packages/LogReaderKit"` with `relativePath = Packages/LogReaderKit;` in the `XCLocalSwiftPackageReference` section and in `PBXProject.packageReferences`.
2. `XCSwiftPackageProductDependency` with `productName = LogReaderKit;` in its section and in `PBXNativeTarget.packageProductDependencies`.
3. `PBXBuildFile` `LogReaderKit in Frameworks` with `productRef` pointing to the product dependency, listed in `PBXFrameworksBuildPhase.files`.

Verify with `xcodebuild -project LogReader.xcodeproj -scheme LogReader -destination 'platform=macOS' build`.

### 4.2 Ports (`Application/Ports`, one protocol per file)

```swift
public protocol KeyValueStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func double(forKey defaultName: String) -> Double
    func integer(forKey defaultName: String) -> Int
    func dictionary(forKey defaultName: String) -> [String: Any]?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}
public protocol BookmarkRepository: AnyObject {
    func bookmarks(for url: URL) -> Set<Int>
    func save(_ offsets: Set<Int>, for url: URL)
}
@MainActor public protocol Pasteboard: AnyObject {
    func write(text: String)
    func write(fileURL: URL)
}
@MainActor public protocol FileRevealer: AnyObject {
    func reveal(_ url: URL)          // select in Finder
    func open(_ url: URL)            // default app, or open a folder
}
@MainActor public protocol FileDialogs: AnyObject {
    func chooseLogFile() -> URL?
    func chooseSaveLocation(suggestedName: String) -> URL?
    func present(_ error: any Error)
}
public protocol FileCopier: AnyObject {
    func copy(_ url: URL, to destination: URL, replacing: Bool) throws
}
@MainActor public protocol AppearanceApplier: AnyObject {
    func apply(_ appearance: Appearance)
}
public protocol LogDiscovery: Sendable {
    func scan(bundleIDPrefix: String) -> [SimulatorDevice]
}
public protocol LogSourceFactory: AnyObject {
    func makeSource(for url: URL) -> any LogSource
}
```

### 4.3 Infrastructure

- `UserDefaults+KeyValueStore.swift`: `extension UserDefaults: KeyValueStore {}` (the methods already match).
- `UserDefaultsBookmarkRepository`: the old `BookmarkStore`, takes `any KeyValueStore`.
- `FileTailerSourceFactory`: `init(readDelay:pollInterval:)`, returns `LogFileTailer`.
- `SimulatorLogDiscovery`: `init(devicesDirectory:)`, builds `SimulatorLogScanner(devicesDirectory:bundleIDPrefix:)` per scan. Also `public static var defaultDevicesDirectory` moved here or kept in the scanner, one place only.
- `FileManagerCopier`: `FileManager.default` copy with optional replace.

### 4.4 Settings

`Appearance`, `TimeZoneMode`: plain enums, `String` raw values, `CaseIterable`, `Sendable`. No `title`, no `nsAppearance`.

`AppSettings` (`@MainActor @Observable public final class`): the same properties as today. `init(store: any KeyValueStore)` reads the stored values. `didSet` writes back. No appearance side effect. `selectNextAppearance`, `increaseFontSize`, `decreaseFontSize`, `resetFontSize` stay. Keys stay the same strings so existing preferences survive.

### 4.5 Session

`SearchMode`: `filter`, `find`. `LogSessionStatus`: `loading`, `live`, `missing`.

`LogFilterState` (struct, `Sendable`, `Equatable`):

```swift
public struct LogFilterState: Sendable, Equatable {
    public var searchText: String
    public var searchMode: SearchMode
    public var searchScope: SearchScope
    public var facets: FacetSelection
    public var bookmarksOnly: Bool

    public init(searchScope: SearchScope)         // text "", mode .filter, facets .all, bookmarksOnly false
    public var hasActiveFilters: Bool             // filter is not pass-through, or find mode with text
    public func makeFilter(bookmarks: Set<Int>) -> LogFilter   // text only in .filter mode; onlyOffsets when bookmarksOnly
    public var findQuery: TextQuery?              // only in .find mode
    public mutating func clear()                  // text, facets, bookmarksOnly; keeps mode and scope
}
```

`FilterRequest`, `FilterResult` (structs, `Sendable`). `FilterResult.compute(_ request: FilterRequest) throws -> FilterResult` runs `LogFilterEngine.indices` then `textMatches` when a query exists. This is the only place that calls the engine.

`LogFilterRunner` (`@MainActor public final class`):

```swift
public init(debounce: Duration)
public func run(_ request: FilterRequest, debounced: Bool) async -> FilterResult?   // cancels the previous run; nil when cancelled
public func cancel()
```

`LogRowsEvent`: `reload`, `inserted(Range<Int>)`, `refreshRows`, `select(row: Int)`, `scrollToEnd`. `LogRowsObserver` (`@MainActor`, `AnyObject`): `func handle(_ event: LogRowsEvent)`.

`LogSession` (`@MainActor @Observable public final class`). State: `url`, `status`, `content`, `facetCounts`, `visible`, `findMatches`, `findMatchSet`, `bookmarks`, `newEntriesWhileDetached`, `isFiltering`, `filterState` (all `private(set)`), `selectedRecords`, `isFollowing`. `@ObservationIgnored public weak var rowsObserver: (any LogRowsObserver)?`.

`init(url:source:bookmarkRepository:filterRunner:searchScope:)` where `source: any LogSource` is created by the factory. `start()` loads bookmarks and begins `for await` on `source.events()`. `stop()` cancels.

Methods (same behavior as `LogDocument` today): `record(atRow:)`, `recordIndex(atRow:)`, `record(at:)`, `previousRecord(before:)`, `text(of:)`, `isBookmarked(_:)`, `primarySelection`, `findPosition`, `jumpToEnd`, `select(recordIndex:)`, `goToEntry(number:)`, `findNext`, `findPrevious`, `nextBookmark`, `previousBookmark`, `toggleBookmarks(recordIndices:)`, `toggleBookmarkForSelection`, `showInFullLog(recordIndex:)`, `clearFilters`, `setSearchText(_:)` (debounced), `setSearchMode(_:)`, `setSearchScope(_:)`, `toggleSearchScope(_:)`, `toggleFacetValue(_:in:)`, `showOnly(_:in:)`, `showAll(in:)`, `setLevels(_:)`, `setBookmarksOnly(_:)`.

Internals: `handle(_ event: LogSourceEvent)`, `appendVisible(_:)` (synchronous path for pass-through or small ranges), `scheduleRefilter(debounced:)` via `LogFilterRunner`, `apply(_:upperBound:)`. Navigation uses `SortedIndices`. Facet counting uses `FacetCounts.add`. No `NSPasteboard`, no `AppKit`.

`LogSessionFactory` (protocol) with `makeSession(url: URL, searchScope: SearchScope) -> LogSession`, and `DefaultLogSessionFactory` (struct in the same folder) that holds `sourceFactory`, `bookmarkRepository`, `debounce`.

### 4.6 Workspace

`SidebarStore` (`@MainActor @Observable`): `devices`, `openedFiles`, `collapsedAppIDs`, `weak var observer: (any SidebarStoreObserver)?`. `init(discovery: any LogDiscovery, scanInterval: Duration)`. `start(bundleIDPrefix:)`, `stop()`, `addOpenedFile`, `removeOpenedFile`, `app(containing:)`, `device(containing:)`. `SidebarStoreObserver.devicesDidChange()`.

`NewestFilePolicy` (enum, pure): `latestFiles(in devices: [SimulatorDevice]) -> [String: String]` (app id → newest file path) and `fileToOpen(current: URL, previousLatest: [String: String], devices: [SimulatorDevice]) -> URL?` with the same rule as `openNewestFileIfNeeded` today.

`Workspace` (`@MainActor @Observable`): `sidebar`, `session`, `weak var observer: (any WorkspaceObserver)?`. `init(sidebar:sessionFactory:settings:)`. `start()`, `stop()`, `restartDiscovery()`, `open(_:)`, `openExternal(_:)`. Persisting `searchScope` happens in `MainViewModel` or `SearchViewModel` through `settings.searchScope = ...` when the session scope changes (no closure). `WorkspaceObserver.workspace(_:didChangeSession:)`.

### 4.7 Use cases

- `CopyEntries`: `init(pasteboard:)`, `copy(recordIndices:from session:)`, `copySelection(of:)`, `copyVisible(of:)`, `copy(text:)`.
- `FileActions`: `init(pasteboard:revealer:dialogs:copier:)`, `reveal`, `openInDefaultApp`, `openFolder`, `copyPath`, `copyFileName`, `copyFile`, `copyText`, `saveCopy(of:)` (suggested name from a private `shareableName(for:)`, `:` → `-`; copy with replace, then reveal, errors through `dialogs.present`).

### 4.8 Tests

`Fakes/` as listed in section 2. `LogFixtures` builds a `LogBatch` from a text fixture (reuse the text from the core tests). Tests: `AppSettingsTests` (round trip through `InMemoryKeyValueStore`, clamping, next appearance), `LogFilterStateTests`, `LogFilterRunnerTests` (cancellation of a superseded run), `LogSessionTests` (append, filter, find next/previous, bookmarks persist, reset clears, follow counter, select), `SidebarStoreTests` (change notification only when devices differ), `NewestFilePolicyTests`, `WorkspaceTests` (open replaces session, external file added to the list, follow newest file), `CopyEntriesTests`, `FileActionsTests`, `UserDefaultsBookmarkRepositoryTests`.

## 5. Phase 3: kit package, presentation layer

Goal: every string, number and style token the views show is produced here and tested here.

### 5.1 Models

```swift
public enum TextStyle: Sendable, Equatable {
    case message(LogLevel?), preview, title, fieldKey, fieldValue, globalMatch, localMatch
}
public struct StyledText: Sendable, Equatable {
    public struct Span: Sendable, Equatable { public let range: NSRange; public let style: TextStyle }
    public let string: String
    public let spans: [Span]       // base spans first, match spans last
}
public struct LogRowItem: Sendable, Equatable {
    number: Int, time: String, fullDate: String, delta: String, level: LogLevel?, levelCode: String,
    tags: String, category: String, source: String, message: StyledText, isBookmarked: Bool, isFindMatch: Bool
}
public struct EntryHeaderItem: Sendable, Equatable {
    public struct MetadataRow: Sendable, Equatable, Identifiable { title, value; id = title }
    number: Int, level: LogLevel?, levelTitle: String, isBookmarked: Bool, metadata: [MetadataRow], sizeText: String
}
public struct EntryTextLayout: Sendable, Equatable { text: StyledText, localMatches: [NSRange] }
public struct SidebarFileItem: Identifiable, Hashable, Sendable { id: String (path), url, title, sizeText, isNewest }
public struct SidebarAppItem: Identifiable, Hashable, Sendable { id, bundleID, logsURL, files, newestFileURL: URL? }
public struct SidebarDeviceItem: Identifiable, Hashable, Sendable { id (udid), name, runtime, isBooted, folderURL (from SimulatorDevice.folderURL), apps }
public struct FacetValueItem: Identifiable, Hashable, Sendable { id, value, title, count, isSelected }
public struct LevelOption: Identifiable, Hashable, Sendable { level, title, isOn; id = level }
public struct SearchScopeOption: Identifiable, Hashable, Sendable { scope, title, isOn; id = scope.rawValue }
public struct SearchModeOption: Identifiable, Hashable, Sendable { mode, title; id = mode }
public struct StatusBarItem: Sendable, Equatable {
    public enum Kind: Sendable { case loading, live, missing }
    kind, entriesText, sizeText, isFiltering, isFollowing, jumpTitle: String
}
@MainActor public struct ContextMenuItem { title: String, isEnabled: Bool, action: () -> Void }
@MainActor public enum ContextMenuEntry { case item(ContextMenuItem), separator }
```

### 5.2 Formatting and display

- `TimeTextFormatter(timeZoneMode:)`: `time(_:)`, `fullDate(_:)`; cached `DateFormatter`s as static lets.
- `DeltaTextFormatter.text(from:to:)`: same output as today.
- `FileSizeText.file(_ bytes: Int64)`, `FileSizeText.memory(_ bytes: Int64)`.
- `LogFileTitle.title(for url:)` (drops `log-`). The shareable name lives in `FileActions.shareableName(for:)`; do not duplicate it.
- `MessageTextBuilder(highlight: TextQuery?)`: `rowMessage(for record:) -> StyledText` (message span with level, preview span, match spans), `expandedMessage(text:messageLength:level:) -> StyledText`.
- `EntryTextLayoutBuilder(globalQuery:localQuery:)`: `layout(for details: LogEntryDetails) -> EntryTextLayout` with `title`, `fieldKey`, `fieldValue` spans, then global and local match spans.
- `StatusBarItemBuilder.item(for session: LogSession) -> StatusBarItem`.
- Display extensions: `Appearance.displayName`, `Appearance.symbolName`; `TimeZoneMode.displayName`; `SearchMode.displayName`, `SearchMode.prompt`; `SearchScope.displayName` (for one option) and `SearchScope.allOptions` stays in the core; `FacetColumn.displayName`.

### 5.3 View models

All `@MainActor @Observable public final class`, `init` assigns only.

- `SettingsViewModel(settings:)`: pass-through properties with get and set for every setting, `appearanceOptions`, `timeZoneOptions`, `fontSizeRange`, `fontSizeText`, `appearanceSymbolName`, `expandRowsTitle`, `expandRowsSymbolName`, `expandRowsHelp`, `selectNextAppearance`, `increaseFontSize`, `decreaseFontSize`, `resetFontSize`, `toggleExpandRows`.
- `MainViewModel(workspace:settings:fileDialogs:copyEntries:)`: conforms to `WorkspaceObserver`. Owns `sidebar: SidebarViewModel`, `sessionViews: SessionViewModels?`, `isInspectorPresented`, `isGoToEntryPresented`, `searchFocusRequest`, `inspectorSearchFocusRequest`. Computed `title`, `subtitle`, `hasSession`, `entryCount`, `status: StatusBarItem?`, `followSymbolName`. Methods `start`, `stop`, `openFile`, `openDropped(_:)`, `restartDiscovery`, `goToEntry(number:)`, `requestSearchFocus`, `requestInspectorSearchFocus`, `toggleInspector`, `showInspector`, `jumpToEnd`, `copyVisible`, `copySelection`, `findNext`, `findPrevious`, `toggleBookmark`, `nextBookmark`, `previousBookmark`, `toggleBookmarksOnly`, `clearFilters`, `canFindInEntry`, `canFindNext`.
- `SessionViewModels` (struct): `session`, `table`, `search`, `inspector`, `filterMenu`. Built by `MainViewModel` when the workspace session changes.
- `SidebarViewModel(workspace:fileActions:)`: `selectedFileID` (get from the session url, set opens), `devices: [SidebarDeviceItem]`, `openedFiles: [SidebarFileItem]`, `isEmpty`, `isExpanded(appID:)`, `setExpanded(_:appID:)`, `open(_:)`, `removeFromList(_:)`, and the file and device actions that forward to `FileActions`.
- `LogTablePresenter(session:settings:copyEntries:)`: conforms to `LogRowsObserver`, holds `weak var receiver: (any LogTableUpdateReceiver)?`. `rowCount`, `row(at:) -> LogRowItem?`, `expandedMessage(at:) -> StyledText?`, `lineCount(row:columns:maxLines:)`, `isFacetActive(_:)`, `headerTitle(for:)`, `headerToolTip(for:)`, `facetFilterViewModel(for:)`, `contextMenu(forRows:showDetails:) -> [ContextMenuEntry]`, `selectionDidChange(rows:)`, `setFollowing(_:)`, `isFollowing`, `copySelection()`. `LogTableUpdateReceiver.apply(_ event: LogRowsEvent)`.
- `SearchViewModel(session:settings:)`: `text` (get and set), `mode`, `modeOptions`, `scopeOptions`, `isScopeDefault`, `scopeSummary`, `prompt`, `showsFindControls`, `positionText`, `canNavigate`, `findNext`, `findPrevious`, `clear`, `toggleScope(_:)`, `useMessageScope`, `useAllScopes`. Writing the scope also writes `settings.searchScope`.
- `FilterMenuViewModel(session:)`: `levelOptions`, `toggle(_ level:)`, `showErrorsAndFaults`, `showWarningsAndAbove`, `showAllLevels`, `isAllLevels`, `bookmarksOnly` (get and set), `hasActiveFilters`, `clearFilters`.
- `FacetFilterViewModel(session:column:)`: `title`, `hint`, `isActive`, `showsSearchField`, `values(matching query:) -> [FacetValueItem]`, `toggle(_:)`, `only(_:)`, `clear()`.
- `EntryInspectorViewModel(session:settings:copyEntries:)`: `entrySearchText`, `currentMatch`, `header`, `layout`, `isLoading`, `focusRange`, `matchCountText`, `canNavigateMatches`, `loadKey` (Hashable, from selection, search text, entry search text, font size), `load() async`, `nextMatch`, `previousMatch`, `copyEntry`, `copyMessage`, `copyItems: [ContextMenuItem]`, `clearEntrySearch`.
- `RowContextMenuModel.entries(session:recordIndices:copyEntries:showDetails:) -> [ContextMenuEntry]`: the same items as `LogRowMenuBuilder` today.

### 5.4 Tests

One test file per view model and per formatter. `LogTablePresenterTests` checks that a row item has the right strings and spans, and that events reach a fake receiver. `EntryInspectorViewModelTests` checks loading, match navigation and copy. `SidebarViewModelTests` checks item mapping and that `selectedFileID` opens the file. `SearchViewModelTests` checks scope persistence in settings. `MainViewModelTests` checks that session view models are rebuilt when the workspace session changes.

## 6. Phase 4: app target

Goal: views use the kit only, one type per file, AppKit adapters in `Platform`, the composition root in `App`. The old `Store` folder is deleted. `Scripts/check-layers.sh` passes.

### 6.1 Composition root

`App/AppDependencies.swift`:

```swift
@MainActor
final class AppDependencies {
    let settings: AppSettings
    let settingsViewModel: SettingsViewModel
    let appearanceApplier: any AppearanceApplier

    static func live() -> AppDependencies
    func makeMainViewModel() -> MainViewModel
}
```

`live()` builds: `UserDefaults.standard`, `SystemPasteboard`, `WorkspaceFileRevealer`, `AppKitFileDialogs`, `FileManagerCopier`, `AppKitAppearanceApplier`, `UserDefaultsBookmarkRepository`, `FileTailerSourceFactory(readDelay: 80 ms, pollInterval: 1 s)`, `SimulatorLogDiscovery`, `AppSettings`, `DefaultLogSessionFactory(debounce: 150 ms)`, `CopyEntries`, `FileActions`. `makeMainViewModel()` builds `SidebarStore(scanInterval: 3 s)`, `Workspace`, `MainViewModel`.

`LogReaderApp`: `@State private var dependencies = AppDependencies.live()`. `WindowGroup { MainView(model: dependencies.makeMainViewModel()) }` with `.environment(dependencies.settingsViewModel)`. `Settings { SettingsView() }` with the same environment. `LogCommands(settings: dependencies.settingsViewModel)`.

`MainView` applies the appearance: `.task { dependencies.appearanceApplier.apply(settings.appearance) }` and `.onChange(of: settings.appearance)`. Pass the applier through the environment key `\.appearanceApplier` or as an init argument of `MainView`; pick the init argument.

### 6.2 Platform

`SystemPasteboard`, `WorkspaceFileRevealer`, `AppKitFileDialogs` (open panel, save panel, `NSAlert(error:)`), `AppKitAppearanceApplier`, `Appearance+NSAppearance` (`var nsAppearance: NSAppearance?`).

### 6.3 Theme

- `LogColors`: unchanged, moved.
- `LogFonts`: `static func monospaced(_ size: Double, weight: NSFont.Weight) -> NSFont`.
- `LevelColors`: `text(for level: LogLevel?) -> NSColor`, `message(for:)`, `rowTint(for:)`. These are the only places that switch over `LogLevel` in the app.
- `TextStyleSheet(fontSize:)`: `attributes(for style: TextStyle) -> [NSAttributedString.Key: Any]`, `baseAttributes`, `wrapsByCharacter: Bool` variant for expanded rows.
- `StyledText+NSAttributedString`: `extension NSAttributedString { convenience init(_ text: StyledText, sheet: TextStyleSheet) }`. Applies spans in order; match spans set background and `LogColors.matchText`.

### 6.4 Features

- `MainView(model:appearanceApplier:)`: layout only. Toolbar content calls `model` methods. `SearchBar(model: sessionViews.search, isFocused:)`, `FilterMenu(model:)`, `ThemeMenu()` (reads `SettingsViewModel` from the environment), `StatusBar(item:onJumpToEnd:)`, `GoToEntrySheet(entryCount:onGo:)`.
- `SidebarView(model:)`, `DeviceHeader(item:)`, `FileRow(item:)`, three context menu views that take an item and the `SidebarViewModel`.
- `LogTableView(presenter:settings:)` as `NSViewRepresentable`. `LogTableCoordinator` keeps install, attach, `apply(_ event:)`, selection sync, scrolling and follow detection. `LogTableRowHeightCache(presenter:lineHeight:columns:)` owns the cache and the recalculation. `LogCellConfigurator(sheet:)` fills a `LogCellView` from a `LogRowItem`. `LogRowMenuBuilder` turns `[ContextMenuEntry]` into `NSMenuItem`s. `FacetFilterView(model:)` and `FacetFilterRow(item:onToggle:onOnly:)`.
- `EntryInspectorView(model:searchFocusRequest:)`, `EntryHeaderView(item:copyItems:onCopy:)`, `EntrySearchBar(model:isFocused:)`, `EntryTextView(text:focusRange:)` unchanged.
- `SettingsView()` reads `SettingsViewModel` from the environment.
- `LogCommands(settings:)` uses `@FocusedValue(\.mainViewModel)`.

### 6.5 Checks

- `xcodebuild ... build` green.
- `Scripts/check-layers.sh` green.
- `rg "LogDocument|BookmarkStore|SidebarModel|LogCellFormatter|EntryTextRenderer" LogReader Packages` finds nothing.
- Launch the app and open a log file: live tail, filter, find, bookmarks, expand rows, inspector search, context menus and the sidebar menus work as in `README.md`.

## 7. Phase 5: docs and cleanup

- `docs/architecture.md`: rewrite the layer section and the window model for the three modules. Keep the data flow and the performance table.
- `CHANGELOG.md`: one `Changed` entry under `Unreleased`.
- `CLAUDE.md`: structure table for the new tree (done together with the rules in `.claude/rules/`).
- `README.md`: no user-facing change.

## 8. Out of scope

Roadmap items (devices, `os_log` stream, tabs, presets, regex, export, JSON tree, mark) are not part of this refactoring. They become easier after it: a new source is a `LogSource` plus a `LogDiscovery`, a preset is a `LogFilterState` value, an export is a use case with a `FileDialogs` port.

## 9. Differences between the plan and the code

- `FacetSelection`: converting level codes that match no `LogLevel` gives `.all`, not an empty `.only` that hides every row.
- `FilterRequest` carries a `range`, so the synchronous append path also goes through `FilterResult.compute`.
- `LogFilterRunner` keeps a generation counter; a run that finishes after a newer one started returns `nil`.
- `LogDiscovery.scan(bundleIDPrefix:)` takes the prefix per scan. `SimulatorLogDiscovery.defaultDevicesDirectory` is the one place for the default path. `SimulatorDevice.folderURL` carries the device folder for the sidebar menu.
- `LogSessionFactory` and `DefaultLogSessionFactory` are `@MainActor`. `WorkspaceObserver.workspace(_:didChangeSession:)` takes a non-optional session.
- `MainViewModel.init` takes `sidebar:`, because `init` may not build a `SidebarViewModel`. `RowContextMenuModel` is an enum with a static `entries(...)` and takes `settings:` to persist the search scope.
- `TextStyle` has a `detail` case for the body of an expanded row. UI models carry ready strings (`numberText`, `countText`); `FacetColumn.columnTitle` is the header title and `displayName` the popover title.
- `LogTableView` takes plain values (`fontSize`, `timeZoneMode`, `showDeltaColumn`, `expandsRows`) and two closures, not `settings:`. `GoToEntrySheet(prompt:onGo:)`. `LogTableRowHeightCache` takes its inputs per call. `LogFileContextMenu` has `showsRemoveFromList`.
- `StatusBar(model:)` reads `model.status` in its own body, so an append does not re-evaluate `MainView`.
- `KeyValueStore.standardDefaults` exists because the app may not name `UserDefaults`.
- `LogTableCoordinator.swift` (320 lines) and `LogSession.swift` (321 lines) are above the 250-line guide. Candidates for a later split: the delegate and data source conformances of the coordinator; the find and bookmark navigation of the session.

## 10. Still to verify by hand

The automated checks cover the build, the layer rules and 174 unit tests. The smoke test launched the app and saw the sidebar rows, but did not open a file. Open a file and check: live tail, Filter and Find with the match counter, column filters, the row context menu (items enabled and disabled), bookmarks and their tint, Expand Rows heights after a column resize, the inspector with its search, the sidebar context menus, Save a Copy, the theme and font size commands.
