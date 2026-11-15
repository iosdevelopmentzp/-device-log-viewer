# Feature plan

The features the user marked "Next" in the tracker, in the order they are built. Each section is the design an implementer follows. The rules in `.claude/rules/` and the workflow in `.claude/skills/add-feature/SKILL.md` apply to every section. One feature group per implementation run. Nothing is committed unless the user asks.

Status words: `todo`, `doing`, `done`.

| # | Feature | Size | Status |
|---|---|---|---|
| 1 | Move a file to Trash, delete older files of an app, delete all logs of a simulator | S | done |
| 2 | Clear all bookmarks, copy entry as JSON | S | done |
| 3 | Exclude a value | S | done |
| 4 | Active filter chips above the table | S | done |
| 5 | Sidebar search and "booted only" | S | done |
| 6 | History of recent searches and filters | M | done |
| 7 | Saved filter presets | L | done |
| 8 | Open the source line in Xcode | M | done |
| 9 | Time range filter and "Mark now" | L | done |
| 10 | Regex search | L | done |
| 11 | Collapse repeated entries | M | done |
| 12 | Alert on a new error while the window is in the background | M | done |
| 13 | Export the visible entries to a file | L | done |
| 14 | JSON tree in the inspector | L | done |
| 15 | Several windows or tabs | L | done |
| 16 | Clear the view: hide entries before, after, selected or all, with a restore banner | M | done |
| 17 | Search inside every file of an app from the sidebar | M | done |
| 18 | Clickable links and word highlight in the inspector | S | done |
| 19 | Extra search conditions without a syntax | M | done |
| 20 | Column visibility, row density and font family | S | done |
| 21 | Log files of a connected iPhone (USB or Wi-Fi) | L | done |
| 22 | Self-update from the local `main` branch | L | done |
| 23 | Log profiles: the log format is configured per project | XL | done |

Every run ends with the five checks (`swift test` in both packages, `xcodebuild`, `Scripts/check-layers.sh`, and the perf test when `Parsing` or `Filtering` changed), a `CHANGELOG.md` entry under `Unreleased`, and `README.md` when a menu, shortcut or setting changes.

## 1. Delete log files

User-visible:

- File context menu (simulator files and "Opened Files"): **Move to Trash**. No confirmation. Trash is reversible.
- App context menu: **Delete Older Files…** (keeps the newest file) and **Delete All Logs…**. Both ask for confirmation. The dialog names the number of files: "Move 12 older log files of com.example.chat to Trash?".
- Simulator context menu: **Delete All Logs of This Simulator…** with the same kind of confirmation. It covers every app shown under the simulator.
- When the open file is trashed, the newest remaining file of the same app opens. If there is none, the session stays and the status bar shows "File removed" (the tailer reports `.missing` on its own).
- The sidebar drops the files at once, not after the next 3 second scan.

Design:

- Port `Application/Ports/FileTrasher.swift`: `protocol FileTrasher: AnyObject { func trash(_ url: URL) throws }`. Adapter `Infrastructure/FileManagerTrasher.swift` on `FileManager.trashItem(at:resultingItemURL:)`. Fake `FakeFileTrasher` records `trashedURLs` and throws `errorToThrow` when set.
- Port `FileDialogs` gets `func confirm(title: String, message: String, confirmTitle: String) -> Bool`. `AppKitFileDialogs` shows an `NSAlert` with a destructive confirm button. `FakeFileDialogs` gets `confirmAnswer` and records `confirmations`.
- Pure decision `Application/Workspace/LogCleanupPolicy.swift` (enum, static functions, tests): `olderFiles(of: AppLogContainer) -> [URL]` (every file except the newest, by `createdAt`), `allFiles(of: AppLogContainer) -> [URL]`, `allFiles(of: SimulatorDevice) -> [URL]`.
- Use case `Application/UseCases/DeleteLogFiles.swift` (trasher + dialogs): `trash(_ url: URL) -> [URL]`, `deleteOlderFiles(of app: AppLogContainer) -> [URL]`, `deleteAllFiles(of app:) -> [URL]`, `deleteAllFiles(of device:) -> [URL]`. The bulk methods ask for confirmation first and return the trashed URLs (empty when cancelled). A throw stops the loop and `dialogs.present(error)`; files trashed before the error are still returned.
- `Workspace.didTrash(_ urls: [URL])`: removes them from `sidebar.openedFiles`; if the current session's URL is among them, opens the newest remaining file of the same app (`sidebar.app(containing:)` minus the trashed set, newest by `createdAt`); then `sidebar.rescan()`.
- `SidebarStore.rescan()`: cancels the scan task and starts it again with the last `bundleIDPrefix` (store the prefix in a private property).
- `SidebarViewModel`: `trash(_ file:)`, `deleteOlderFiles(of app:)`, `deleteAllFiles(of app:)`, `deleteAllFiles(of device:)`. The view model needs the `AppLogContainer` and `SimulatorDevice` for an item: look them up in `workspace.sidebar.devices` by `id`.
- `AppDependencies`: build `DeleteLogFiles(trasher: FileManagerTrasher(), dialogs: fileDialogs)` and pass it to `SidebarViewModel`.
- Views: `LogFileContextMenu` adds "Move to Trash" (`role: .destructive`) after a divider; `AppContainerContextMenu` adds the two delete items; `DeviceContextMenu` adds one.
- Tests: `LogCleanupPolicyTests`, `DeleteLogFilesTests` (confirm yes/no, error in the middle), `WorkspaceTests` (trashing the open file opens the newest remaining one; trashing another file keeps the session), `SidebarStoreTests` (`rescan` calls discovery again).

## 2. Clear all bookmarks, copy entry as JSON

Clear all bookmarks:

- `LogSession.clearBookmarks()`: empties `bookmarks`, saves through the repository, refilters when `bookmarksOnly` is on, otherwise `notify(.refreshRows)`.
- `MainViewModel.clearBookmarks()` and `hasBookmarks: Bool`.
- `LogCommands`: **Clear All Bookmarks** after "Show Bookmarks Only", disabled when there are none. No shortcut.
- Tests in `LogSessionTests`.

Copy entry as JSON:

- `Application/UseCases/EntryJSONEncoder.swift` (enum, static): `json(number: Int, record: LogRecord, text: String) -> String`. Shape, keys in this order: `number`, `level` (code or null), `time` (ISO 8601 with milliseconds, UTC, or null), `tags` (array), `category`, `source`, `message`, `fields` (object; a field whose `prettyValue` is valid JSON becomes a nested value, every other field a string; a repeated key gets a `#2` suffix). Pretty printed, sorted keys inside `fields` only. Use `LogEntryDetails.parse`.
- `CopyEntries.copyJSON(recordIndex: Int, from session: LogSession)`.
- Row context menu: **Copy as JSON** after "Copy Message". Inspector copy menu: **Copy as JSON** after "Copy Message".
- Tests: `EntryJSONEncoderTests` with a structured entry, an entry without a header, a field with pretty JSON.

## 3. Exclude a value

Core:

- `FacetFilter` gets `case except(Set<Value>)`. `allows(nil)` is true for `.except`. `allowsAny(of:)` under `.except` is true when no value is in the set. `isAll` stays false for `.except`. New `isExcluding: Bool`. `togglingSelection` keeps the mode: under `.except` it adds or removes in the excluded set and returns `.all` when the set becomes empty. New `excluding(_ value: Value) -> FacetFilter`: under `.except` adds the value, otherwise returns `.except([value])`.
- `FacetSelection`: `exclude(_ values: Set<String>, in column: FacetColumn)` (replaces the column filter with `.except(values)`), `isExcluding(_ column:) -> Bool`, `mode(of column:) -> FacetMode` where `enum FacetMode { case include, exclude }` (own file in `Filtering`). `setMode(_:in:)` converts the current set to the other case; an empty set stays `.all`.
- `LogFilterEngine` needs no change beyond what `allows`/`allowsAny` give.
- Tests: `FacetFilterTests`, `FacetSelectionTests`, `LogFilterEngineTests` (tags: an entry with an excluded tag is hidden, an entry without tags is shown).

Kit and app:

- `LogSession.exclude(_ values: Set<String>, in column:)`, `setFacetMode(_:in:)`.
- `RowContextMenuModel`: after the "Show Only …" items, a separator and **Hide Level X**, **Hide Tag #x**, **Hide Category "…"**, **Hide Source "…"** items that call `exclude`.
- `FacetFilterViewModel`: `mode: FacetMode` with get and set, `modeOptions: [FacetModeOption]` (title "Show only checked" / "Hide checked"), `hint` depends on the mode. Header title: "◉" for include, "⊘" for exclude (`LogTablePresenter.headerTitle`).
- `FacetFilterView`: a segmented picker for the mode under the title. `FacetFilterRow`: the hover button reads "Only" in include mode and "Hide" in exclude mode (the row gets `onlyTitle` from the view model through `FacetValueItem.actionTitle`).
- Tests: `FacetFilterViewModelTests`, `RowContextMenuModelTests` (hide items present and acting).

## 4. Active filter chips

- UI model `Presentation/Models/FilterChipItem.swift`: `id: String`, `title: String`, `kind: Kind` (`.search`, `.levels`, `.facet(FacetColumn)`, `.bookmarks`, later `.timeRange`, `.mark`), `isExclusion: Bool`.
- `Presentation/ViewModels/FilterChipsViewModel.swift` (per session, in `SessionViewModels.chips`): `chips: [FilterChipItem]` built from `session.filterState` and `session.findMatches.count` for Find mode. Titles: "Filter: text" / "Find: text (12 matches)", "Level: ERR, FLT" / "Not level: DBG", "Tags: #network, #api" (at most three values, then "+2"), "Category: default", "Source: ApiService", "Bookmarks only". `remove(_ chip:)` clears that one part (`session.setSearchText("")`, `session.showAll(in:)`, `session.setLevels(.all)`, `session.setBookmarksOnly(false)`). `clearAll()`. `isEmpty`.
- View `Features/Toolbar/FilterChipsBar.swift`: a horizontal `ScrollView` of chips (`FilterChip` subview: title, exclusion chips with a strikethrough-like prefix "not", a small ×) and "Clear All" at the end. `MainView.detail` shows it above the table only when the view model has chips. Chips use the theme tokens, exclusion chips tinted with the warning color.
- Tests: `FilterChipsViewModelTests` for titles, truncation and `remove`.

## 5. Sidebar search and "booted only"

- `AppSettings.sidebarShowsBootedOnly: Bool` (key `sidebar.bootedOnly`), `SettingsViewModel` pass-through.
- Pure `Application/Workspace/SidebarFilter.swift`: `static func apply(_ devices: [SimulatorDevice], query: String, bootedOnly: Bool) -> [SimulatorDevice]`. Query matching is case-insensitive on the file name, the bundle ID and the simulator name. A device stays when it has at least one matching file, or when the device name matches (then all of its files stay). Empty query keeps everything. `bootedOnly` drops devices with `isBooted == false`.
- `SidebarViewModel`: `query: String` (plain stored state, per window), `showsBootedOnly: Bool` (get/set through settings), `devices` applies the filter, `isExpanded(appID:)` returns true for every app while the query is not empty, `isFilteredEmpty: Bool` for the "No matches" state, `bootedCountText` ("3 of 7 simulators").
- `SidebarView`: a header row above the list with a search `TextField` (magnifier icon, clear button, `.textFieldStyle(.roundedBorder)`, `controlSize(.small)`) and a toggle button with `power` symbol and help "Show only running simulators". `ContentUnavailableView.search` when the query hides everything.
- Tests: `SidebarFilterTests`, `SidebarViewModelTests`.

## 6. History of recent searches and filters

Data:

- `Application/Settings/SearchHistory.swift`: `struct SearchHistory: Codable, Equatable, Sendable { entries: [RecentSearch] }` with pure methods `adding(_ entry:)` (moves an equal text+mode to the top, keeps `isPinned`, caps at 30 unpinned), `removing(id:)`, `togglingPin(id:)`, `clearingUnpinned()`. `RecentSearch { id: UUID, text, mode: SearchMode, scope: SearchScope, date: Date, isPinned }`. Pinned entries sort first, then by date. `SearchScope` and `SearchMode` need `Codable` (core types, add the conformance in the core).
- `Application/Settings/FilterHistory.swift`: `FilterHistory { entries: [RecentFilterSet] }`, `RecentFilterSet { id, levels: FacetFilter<LogLevel>, facets: FacetSelection, bookmarksOnly, date }`, cap 10, dedupe by equal filter. `FacetFilter` and `FacetSelection` get `Codable` in the core.
- `AppSettings.searchHistory` and `filterHistory`, stored as JSON `Data` under `search.recent` and `filters.recent` (`JSONEncoder`/`JSONDecoder` with ISO 8601 dates). A decode failure gives an empty history.

Recording:

- `SearchViewModel.commitSearch()`: records the current text, mode and scope when the text is not empty. The view calls it on submit and when the field loses focus.
- Filter sets: `LogSession` exposes nothing new; `FilterMenuViewModel` owns a `Task` that waits 3 seconds after every `filterState` change (`withObservationTracking` or a check in `onChange` from the view) and records a non-pass-through facet state through `settings.filterHistory = settings.filterHistory.adding(...)`. Simplest: `MainView` observes `views.session.filterState` with `.onChange` and calls `views.filterMenu.noteFilterChanged()`, which debounces inside the view model.

UI:

- Search bar: a button with `clock.arrow.circlepath` left of the scope menu, help "Recent searches". It opens a popover with `SearchHistoryView(model: SearchHistoryViewModel)`: a filter field at the top, a `List` with rows (text in one line, small tags for mode and scope summary, relative time through `RelativeDateTimeFormatter` cached as `static let`, a pin toggle, a remove button), and "Clear History" at the bottom. Click or Return on a row applies text, mode and scope to the session and closes the popover. Arrow keys move the selection (List selection). The button is disabled when the history is empty.
- `SearchHistoryViewModel` (kit): `items: [RecentSearchItem]` (UI model with `id`, `text`, `modeTitle`, `scopeTitle`, `timeText`, `isPinned`), `filterText`, `apply(_ item:)`, `remove`, `togglePin`, `clear`. It takes the session and the settings.
- Filters menu: a **Recent Filters** submenu with up to 10 entries, each titled by a summary ("ERR, FLT · #network · Bookmarks"), applying the set through `session.applyFacets(_:bookmarksOnly:)` (one refilter). The summary builder is a static function with tests.
- Tests: `SearchHistoryTests`, `FilterHistoryTests`, `SearchHistoryViewModelTests`, `AppSettingsTests` for persistence round trip.

## 7. Saved filter presets

- `Application/Settings/FilterPreset.swift`: `struct FilterPreset: Codable, Identifiable, Equatable, Sendable { id: UUID, name, searchText, searchMode, searchScope, facets: FacetSelection, bookmarksOnly }`. `AppSettings.filterPresets: [FilterPreset]` under `filters.presets` as JSON.
- `LogFilterState.init(preset:)` and `LogSession.apply(_ preset: FilterPreset)` (one state change, one refilter). `LogFilterState.makePreset(name:)`.
- `FilterPresetsViewModel` (kit, per window, in `MainViewModel.presets`): `items: [FilterPresetItem]` (`id`, `name`, `summary`, `shortcutIndex: Int?` for the first nine), `apply(id:)`, `saveCurrent(name:)`, `rename(id:name:)`, `delete(id:)`, `move(from:to:)`, `canSaveCurrent` (the session has active filters).
- UI: Filters menu gets a **Presets** section at the top: one item per preset, then **Save Current Filters as Preset…** and **Manage Presets…**. `PresetNameSheet` (text field, Save, Cancel). `ManagePresetsSheet`: a `List` with editable names, delete buttons and drag reorder. `LogCommands`: a **Presets** submenu in the Log menu with ⌃⌘1…⌃⌘9 for the first nine presets.
- README: the Presets section.
- Tests: `FilterPresetTests` (round trip), `FilterPresetsViewModelTests`, `LogSessionTests.applyPreset`.

## 8. Open the source line in Xcode

- `AppSettings.projectRootPath: String` (key `source.projectRoot`, empty by default). `SettingsView` gets a "Source" section: the path (truncated in the middle) and a **Choose…** button through a new `FileDialogs.chooseFolder() -> URL?` (`NSOpenPanel` with `canChooseDirectories`).
- Core: `Parsing/SourceReference.swift`: `struct SourceReference { fileName: String; line: Int? }` with `static func parse(_ source: String) -> SourceReference?` ("ApiService:229" → "ApiService", 229; "ApiService" → line nil). `LogRecord.sourceReference` computed property. Tests.
- Port `Application/Ports/SourceFileIndex.swift`: `protocol SourceFileIndex: AnyObject { func locate(fileName: String, under root: URL) -> [URL] }`. Adapter `Infrastructure/FileManagerSourceFileIndex.swift`: enumerates the root once per root path (cache keyed by path, invalidated when the root changes), skips `.git`, `.build`, `DerivedData`, `Pods`, `node_modules`, `Carthage`, and maps the base name without extension to URLs. Candidates with `.swift` first, then any other extension. Fake `FakeSourceFileIndex` with `locations: [String: [URL]]`.
- Port `Application/Ports/SourceOpener.swift`: `protocol SourceOpener: AnyObject { func open(_ url: URL, line: Int?) throws }`. Adapter `Infrastructure/XedSourceOpener.swift` runs `/usr/bin/xed` with `--line <n>` and the path through `Process`. Fake records the calls.
- Use case `Application/UseCases/OpenSource.swift` (index + opener + dialogs + settings): `open(record: LogRecord)`. Decisions: no root set → `dialogs.present` an error that says to choose the project folder in Settings; no candidate → error naming the file and the root; several candidates → the shortest path.
- `MainViewModel.openSourceOfSelection()` and `canOpenSource`. `LogCommands`: **Open Source in Xcode** (⌘⇧O) in the Log menu. Row context menu: **Open in Xcode** when the record has a source. Inspector header: the Source value becomes a link-styled `Button` that calls `EntryInspectorViewModel.openSource()`.
- Tests: `SourceReferenceTests`, `OpenSourceTests` with fakes (no root, not found, several candidates).

## 9. Time range filter and "Mark now"

Core:

- `LogFilter` gets `timeRange: ClosedRange<TimeInterval>?` and `startIndex: Int?`. `isPassThrough` includes both. `LogFilterEngine.indices` starts at `max(range.lowerBound, startIndex)` and drops records whose timestamp is nil or outside the range when a range is set.
- Tests in `LogFilterEngineTests`.

Kit:

- `LogFilterState.timeRange`, `markIndex`; both cleared by `clear()`, both count in `hasActiveFilters`.
- `LogSession.setTimeRange(_:)`, `setTimeRangeFromSelection()` (needs at least one selected record; one record gives `timestamp...end of file`, two or more give min…max), `markNow()` (`markIndex = content.records.count`), `clearMark()`, `clearTimeRange()`.
- `TimeRangeViewModel` (kit, sheet): `startText`, `endText`, prefilled from the selection or the first and last visible record, parse with `TimeTextFormatter` in the current `timeZoneMode` (add `parse(_:) -> TimeInterval?` to the formatter, format `yyyy-MM-dd HH:mm:ss.SSS` and also `HH:mm:ss` on the day of the first record), `errorText`, `apply()`.
- Chips (feature 4): `.timeRange` chip "From 22:18:54 to 22:19:30", `.mark` chip "After mark (#1 234)".
- UI: Filters menu: **Time Range…**, **Mark Now** (⌘M), **Clear Mark**. Row context menu: **Show Only Between Selected Entries** when two or more rows are selected, **Show Only From This Entry**. `TimeRangeSheet` in `Features/Main`. `LogCommands` gets Mark Now and Time Range….
- Tests: `LogSessionTests` (mark hides earlier records, new records still appear, clear brings them back), `TimeRangeViewModelTests` (parsing, errors).

## 10. Regex search

Core:

- `TextQuery` gets a kind: `init?(_ text: String)` stays the plain query; `static func regex(_ pattern: String) throws -> TextQuery` compiles an `NSRegularExpression` with `.caseInsensitive` and wraps it in a `@unchecked Sendable` box (the class is immutable and thread safe). `matches(bytes)` for a regex decodes the bytes to a `String` and runs `firstMatch`. `ranges(in:)` uses `matches(in:)`.
- `LogFilter.isRegex: Bool`. `LogFilterEngine` builds the query with the flag; an invalid pattern makes the filter pass through (the view model shows the error instead).
- Tests: `TextQueryTests` (regex matches, ranges, case-insensitivity, invalid pattern throws), `LogFilterEngineTests`.
- Run the performance test. The plain path must stay as it is.

Kit and app:

- `LogFilterState.isRegex` and `findQuery` honoring it. `AppSettings.searchUsesRegex` persisted (key `search.regex`), `LogSession.setRegex(_:)`.
- `SearchViewModel.isRegex` (get/set), `regexError: String?` (compiles the current text when regex is on, nil when fine), `isTextValid`.
- `SearchBar`: a toggle button with a `.*` text label (monospaced) left of the clear button, help "Treat the search as a regular expression", tinted when on. The field border turns to the warning color and the help text shows the error when the pattern is invalid.
- `MessageTextBuilder` and `EntryTextLayoutBuilder` already use `TextQuery.ranges(in:)`; make sure they build the query with the flag.
- Search history (feature 6) records `isRegex` as part of the entry.
- Tests: `SearchViewModelTests`.

## 11. Collapse repeated entries

- Setting `AppSettings.collapsesRepeats: Bool` (key `table.collapseRepeats`, default off). View menu: **Collapse Repeated Entries** (⌘⇧R) in `LogCommands` and a toolbar button next to Expand Rows.
- Pure `Presentation/ViewModels/RowCollapser.swift` (struct with tests): input the visible record indices and a `key(for recordIndex) -> String` closure (message plus level code), plus `expandedGroups: Set<Int>` (first record index of each expanded group). Output `rows: [TableRow]` where `enum TableRow { case single(recordIndex: Int); case group(first: Int, count: Int, isExpanded: Bool); case member(recordIndex: Int, first: Int) }`. Consecutive visible records with the same key form a group when the count is at least 2. An expanded group lists its members after the group row. `append(recordIndices:)` extends the last row when the key matches and returns the table change: `.inserted(range)` and whether the last existing row changed.
- `LogTablePresenter` keeps a `RowCollapser` when the setting is on: `rowCount`, `row(at:)`, `recordIndex(atRow:)` (a group row maps to its first record), `rowForRecord(_:)` (a collapsed member maps to its group row), `toggleGroup(atRow:)`. On `.reload` the collapser rebuilds; on `.inserted(range)` it appends and forwards `.inserted` for the new rows and `.refreshRows` when the last row's count changed. `select(row:)` events from the session carry a record index: the presenter expands the group that holds it before it maps the row.
- `LogRowItem.repeatCount: Int?` and `isGroupMember: Bool`. The Message cell shows a count badge "×12" (own `TextStyle.badge` token, mapped in `TextStyleSheet`) before the message for a group row; a member row is indented by the badge width. A click on the badge area of a group row toggles the group (the coordinator checks the click location against the badge rect and calls `presenter.toggleGroup(atRow:)`).
- `LogSession.visible` stays untouched; copying, bookmarks and Find keep working on record indices.
- Tests: `RowCollapserTests` (grouping, append merging, expand), `LogTablePresenterTests` for the mapping.

## 12. Alert on a new error in the background

- Port `Application/Ports/AppAttention.swift`: `protocol AppAttention: AnyObject { var isAppActive: Bool { get }; var observer: (any AppAttentionObserver)? { get set }; func requestAttention(); func setBadge(_ text: String?) }` and `protocol AppAttentionObserver: AnyObject { func appDidBecomeActive() }` (own file). Adapter `Platform/AppKitAppAttention.swift`: `NSApp.isActive`, `NSApp.requestUserAttention(.informationalRequest)`, `NSApp.dockTile.badgeLabel`, observes `NSApplication.didBecomeActiveNotification`. Fake records calls and lets a test flip `isAppActive`.
- `AppSettings.alertsOnErrors: Bool` (key `alerts.errors`, default on). `SettingsView` gets an "Alerts" section with the toggle "Bounce the Dock icon when an error arrives and the window is in the background".
- `LogSession` gets `@ObservationIgnored public weak var appendObserver: (any LogAppendObserver)?` called from `handle(.batch)` with the appended range (new protocol file `LogAppendObserver`).
- `Application/Session/ErrorAlertController.swift` (`@MainActor`, one per window, owned by `MainViewModel`, attached to the current session on every session change): on append, when the setting is on and `isAppActive == false`, counts records with level `.error` or `.fault` in the range; the first new error in an inactive period calls `requestAttention()`; every new error updates the badge with the running count. `appDidBecomeActive()` clears the badge and the count.
- Tests: `ErrorAlertControllerTests` with a fake attention port and a session harness.

## 13. Export the visible entries

- Port `Application/Ports/FileWriter.swift`: `func write(_ data: Data, to url: URL) throws`. Adapter `Infrastructure/DataFileWriter.swift`. Fake records writes.
- `Application/UseCases/ExportEntries.swift` (dialogs + writer + revealer): `exportVisible(of session: LogSession, format: ExportFormat)`, `enum ExportFormat { case log, json }` (own file). The log format writes the header line `{"v":1,"sep":"\u001e"}` followed by every entry's raw text, `"\n"` and the separator, so the file opens in LogReader again. The JSON format writes an array of the objects from `EntryJSONEncoder`. The data is built in `Task.detached` from a snapshot of `content` and `visible`, then written, then revealed in Finder. A suggested name: the file title with `-filtered` and the extension, colons replaced by `-`.
- `MainViewModel.exportVisible(format:)`, `isExporting` for a status bar spinner (`StatusBarItem.isExporting`).
- `LogCommands`: File menu **Export Visible Entries as Log…** and **Export Visible Entries as JSON…** after "Copy All Visible Entries".
- Tests: `ExportEntriesTests` (a log export re-indexed by `LogIndexer` yields the same number of entries; a JSON export is valid JSON with the right count; cancel writes nothing).

## 14. JSON tree in the inspector

- `Presentation/Models/JSONTreeNode.swift`: `id: String` (key path like `$.items[2].name`), `key: String`, `valueText: String` (scalars: the value, objects: "{3}", arrays: "[12]"), `kind: Kind` (`.object`, `.array`, `.string`, `.number`, `.bool`, `.null`), `children: [JSONTreeNode]`.
- `Presentation/Formatting/JSONTreeBuilder.swift`: `static func build(_ json: String, limit: Int) -> JSONTreeNode?` through `JSONSerialization`; nil when the text is not an object or array or the node count passes `limit` (5 000). Object keys keep their order when possible (fall back to sorted keys).
- `EntryInspectorViewModel`: `jsonFields: [JSONFieldItem]` (`key`, `tree`, `isTreeShown`), `expandedNodeIDs: Set<String>` (first two levels expanded by default when a tree loads), `toggleNode(id:)`, `copyValue(nodeID:)`, `copyKeyPath(nodeID:)`, `copySubtree(nodeID:)`. `AppSettings.inspectorShowsJSONTree: Bool` (key `inspector.jsonTree`, default on) remembered through the settings.
- UI: below the entry text in `EntryInspectorView`, a "JSON" section with a segmented control "Text | Tree" and, for each JSON field, a `JSONTreeView` (`Features/Inspector`): rows rendered with `DisclosureGroup` recursion inside a `LazyVStack`, key in `fieldKey` style, value in `fieldValue` style, container counts in `preview` style, context menu with the three copy actions. When the inspector search text is not empty, the text view stays and the tree collapses to keep the highlighted matches visible.
- Tests: `JSONTreeBuilderTests` (nesting, key paths, limit), `EntryInspectorViewModelTests` for expansion state and copy actions.

## 15. Several windows or tabs

- `LogReaderApp`: `WindowGroup(id: "main", for: URL.self) { $url in MainView(...) }`. `MainView` opens the URL in `.task` when it is set (`model.openExternal(url)`). The launch window has no URL.
- `MainViewModel.windowRequest: WindowRequest?` (`struct WindowRequest: Equatable { id: Int; url: URL? }`) and `openInNewWindow(_ url: URL?)` that bumps it. `MainView.onChange(of: model.windowRequest)` calls `openWindow(id: "main", value: url)`; without a URL, `openWindow(id: "main")`.
- `SidebarViewModel.openInNewWindow(_ file:)` forwards to the main view model through `Workspace`? No: the sidebar view model gets an `onOpenInNewWindow` handed in by `MainViewModel` as a weak observer protocol `SidebarWindowObserver` (one method). Follow the observer rule from `.claude/rules/layers.md`.
- Menus: File **New Window** (⌘N) in `LogCommands` (`CommandGroup(replacing: .newItem)` keeps "Open…" ⌘O and adds New Window); file context menu **Open in New Window**; row context menu unchanged.
- Tabs: set `NSWindow.allowsAutomaticWindowTabbing = true` in the app entry (default on macOS, state it explicitly in `Platform/WindowTabbing.swift` called from `AppDependencies.live()`), so the Window menu offers "Merge All Windows" and the system "Prefer tabs" setting applies. No custom tab bar.
- README: the Window section.
- Verify by hand: two windows with different files, both tail live; closing one keeps the other; ⌘N opens an empty window with the sidebar.

## 16. Clear the view

The user hides entries from the table without touching the file, sees at once that the view is not complete, and brings the entries back in one click. "Mark Now" from section 9 is one case of this ("clear everything that is in the file now, keep showing new entries"); it becomes part of this feature and keeps its shortcut.

User-visible:

- Row context menu: **Clear Entries Before This**, **Clear Entries After This**, **Clear Selected Entries** (with the count when several rows are selected), and **Restore All Entries** when something is cleared. "Before" and "After" keep the clicked entry itself.
- Log menu, a **Clear** section: **Clear All Entries** (⌘⇧M, replaces "Mark Now"; new entries keep arriving), **Clear Entries Before Selected**, **Clear Entries After Selected**, **Clear Selected Entries**, **Restore All Entries** (⌘⇧⌫). The Filters menu gets the same items in place of "Mark Now" / "Clear Mark".
- A banner above the table (above the filter chips), in the warning tint with an `eye.slash` symbol, visible only while something is cleared: "Showing 320 of 1 557 entries · 1 234 cleared before #1 235 · 2 cleared after #1 540 · 3 selected entries cleared", one × per part, and a **Restore All** button. "Cleared after" hides only the entries that exist at the moment of the click. New entries that arrive later stay visible, and the number in that part does not change.
- "Clear Filters" (⌘K) and "Show in Full Log" also restore every cleared entry, because they mean "the full log". Applying a preset keeps the cleared parts.
- The `.mark` chip from section 9 goes away; the banner replaces it. The `.timeRange` chip stays.

Design:

- Core `LogFilter`: keep `startIndex`; add `hiddenRange: Range<Int>?` (records with an index inside the range are hidden; an empty range hides nothing) and `hiddenOffsets: Set<Int>?` (byte offsets of cleared records, stable like bookmarks). `isPassThrough` includes both. `LogFilterEngine.indices` skips an index that `hiddenRange` contains; `matches` drops a record whose offset is in `hiddenOffsets`. Tests in `LogFilterEngineTests`. Run the performance test.
- Kit `LogFilterState`: `markIndex` stays (cleared before), plus `clearedAfterRange: Range<Int>?` and `clearedOffsets: Set<Int>`. `clear()` resets all three. `hasActiveFilters` includes them. `hasClearedEntries: Bool`. `makeFilter` passes them. `apply(preset)` keeps the three values from the current state. `hasPresetContent` ignores them.
- `LogSession`: `clearAllEntries()` (the old `markNow`; keep `markNow()` as a thin alias only if other code still calls it, otherwise rename everywhere), `clearEntries(before recordIndex: Int)` (`markIndex = recordIndex`), `clearEntries(after recordIndex: Int)` (`clearedAfterRange = (recordIndex + 1)..<content.records.count`, nil when the range is empty), `clearSelectedEntries()` (adds the offsets of `selectedRecords`, then empties the selection), `restoreBefore()`, `restoreAfter()`, `restoreSelected()`, `restoreAllEntries()`. A file reset (`.reset`) drops all three, as the mark does today. `clearedCounts: (before: Int, after: Int, selected: Int)` computed: `markIndex ?? 0`, `clearedAfterRange?.count ?? 0`, `clearedOffsets.count`.
- `ClearedEntriesViewModel` (kit, `Presentation/ViewModels`, per session, in `SessionViewModels.cleared`): `isActive`, `summaryText` ("Showing 320 of 1 557 entries", grouped numbers through `GroupedNumberText`), `parts: [ClearedPartItem]` (UI model: `id`, `title` such as "1 234 cleared before #1 235", "2 cleared after #1 540", "3 selected entries cleared", `kind`), `restore(part:)`, `restoreAll()`. The before/after titles use entry numbers (index + 1).
- `FilterChipsViewModel`: remove the `.mark` chip and its kind.
- `RowContextMenuModel`: the four items after "Show in Full Log" (Restore All only when `hasClearedEntries`), the "Clear Selected Entries" title with " (N)" when several rows are selected.
- `MainViewModel`: `clearAllEntries()`, `clearEntriesBeforeSelection()`, `clearEntriesAfterSelection()`, `clearSelectedEntries()`, `restoreAllEntries()`, `canClearAroundSelection` (one selected record), `canClearSelection`, `hasClearedEntries`. Remove `markNow()` / `clearMark()`.
- `FilterMenuViewModel`: the same methods in place of `markNow` / `clearMark`.
- Views: `ClearedEntriesBanner` (`Features/Toolbar`, takes the view model; the emptiness check lives inside its `body`, like `FilterChipsBar`), placed in `MainView.detail` in the same `safeAreaInset(edge: .top)` above `FilterChipsBar` inside a `VStack(spacing: 0)`. Colors: add `LogColors.clearedBannerBackground` (warning color at low opacity) and reuse `warningText`. `ClearedPartChip` subview (title plus ×, help "Restore these entries"). `LogCommands` and `FilterMenu` updated as above.
- README: replace the Mark Now paragraph with a "Clear the view" paragraph and update the shortcut table. CHANGELOG: one line under Added and one under Changed (Mark Now renamed).
- Tests: core `LogFilterEngineTests` (hiddenRange, hiddenOffsets). Kit: `LogSessionTests` (each clear hides the right records and new entries still arrive after "clear all" and stay visible after "clear after"; each restore; a reset drops everything; `apply(preset)` keeps the cleared parts; `clearFilters` restores), `ClearedEntriesViewModelTests` (summary, parts, restore), `FilterChipsViewModelTests` (no mark chip), `RowContextMenuModelTests`, `MainViewModelTests`, `FilterMenuViewModelTests`.

## 17. Search inside every file of an app

User-visible:

- The sidebar header gets a second mode for the filter field: a toggle button with `doc.text.magnifyingglass` and help "Search inside files". When it is on, the typed text is searched inside the contents of every log file that the sidebar shows (after the "booted only" filter and the bundle prefix). Files with no match disappear, the others show a badge "12 matches" in the row; apps and simulators without a matching file disappear. A spinner in the header while the search runs, "No matches in any file" when nothing matches.
- A click on a result opens the file and puts the text into the main search field in Find mode, so the matches are highlighted and ⌘G walks through them.
- Typing is debounced by 400 ms. A new text cancels the running search. Files over 200 MB are skipped and show "skipped" instead of a count.

Design:

- Core: `TextQuery.countMatches(in bytes: UnsafeRawBufferPointer) -> Int` (plain: the ASCII fast path loop until the end; non-ASCII and regex: decode and count). Tests.
- Port `Application/Ports/FileContentSearcher.swift`: `protocol FileContentSearcher: AnyObject, Sendable { func countMatches(of query: TextQuery, in url: URL, sizeLimit: Int) throws -> FileSearchResult }` with `enum FileSearchResult: Sendable, Equatable { case count(Int), skipped }` (own file). Adapter `Infrastructure/DataFileContentSearcher.swift`: checks the size through `FileManager` attributes, reads with `Data(contentsOf:options: .mappedIfSafe)` and calls `countMatches`. Fake records calls and returns values from a dictionary keyed by path.
- `Application/Workspace/SidebarContentSearch.swift` (`@MainActor @Observable final class`, owned by `SidebarViewModel`): `isEnabled: Bool`, `query: String` (the sidebar query, pushed by the view model), `isSearching: Bool`, `results: [String: FileSearchResult]` keyed by path, `generation`. `update(query:files: [URL])` debounces (`Duration` injected), cancels the previous task, runs the searcher in `Task.detached` per file with `Task.checkCancellation` between files, and publishes results in one batch at the end (or every 20 files). An empty query clears everything.
- `SidebarFilter.apply` gets a fourth parameter `contentResults: [String: FileSearchResult]?`: when not nil, a file stays only when its result is `.count(n)` with `n > 0` or `.skipped`; apps and devices without files are dropped (name matches do not keep anything in this mode). `SidebarFileItem.matchText: String` ("12 matches", "1 match", "skipped", "").
- `SidebarViewModel`: `searchesContents: Bool` (toggle; turning it on starts the search with the current query, off clears results), `isSearchingContents`, `open(_ file:)` in content mode also calls `workspace.session?.setSearchMode(.find)` and `setSearchText(query)` after the file opens (the session is new; set the state right after `workspace.open`). `isFilteredEmpty` and the empty states cover the content mode ("No matches in any file").
- `AppDependencies`: `DataFileContentSearcher()` into `SidebarViewModel` through `SidebarContentSearch`. Add the adapter name to both regexes in `Scripts/check-layers.sh`.
- Tests: core `TextQueryTests.countMatches`; kit `SidebarContentSearchTests` (debounce, cancel, results, skipped, empty query), `SidebarFilterTests` (content mode), `SidebarViewModelTests` (toggle, open sets the session search).

## 18. Clickable links and word highlight in the inspector

- Kit `EntryTextLayoutBuilder` detects links with `NSDataDetector(types: .link)` over the entry text and returns them in `EntryTextLayout.links: [EntryTextLink]` (`range: NSRange`, `url: URL`, own file in `Presentation/Models`). Only `http`, `https` and `file` schemes; mailto is left out.
- App `EntryTextView` adds the `.link` attribute with the URL and `.cursor` pointing hand on those ranges; `NSTextView` opens links itself on click (no `NSWorkspace` in the app view). `linkTextAttributes` use the system link color (`LogColors.link`) with an underline.
- Double click on a word in the entry text (an `NSTextView` subclass `EntryNSTextView` in `Features/Inspector`, `mouseDown` with `clickCount == 2`, then the selected word from `selectedRange`) calls a closure property `onDoubleClickWord` that the representable wires to `EntryInspectorViewModel.highlight(word:)`: it sets `entrySearchText` to the word (the existing inspector search highlights every occurrence and shows the counter). A single click elsewhere does not clear it; the × in the search bar does.
- Context menu of the text view: **Search for “word” in Log** when there is a selection (through the representable's coordinator, calls `EntryInspectorViewModel.searchInLog(text:)` that sets the session to Find mode with that text).
- Tests: `EntryTextLayoutBuilderTests` (links found with ranges; mailto ignored), `EntryInspectorViewModelTests` (`highlight(word:)`, `searchInLog`).

## 19. Extra search conditions without a syntax

User-visible: a `+` button (`plus.circle`) at the end of the search field adds a condition row in a bar under the toolbar (below the cleared banner and the chips): a popup with "Also contains" / "Does not contain", a text field, and ×. Up to three extra conditions. Every condition must hold (AND). They apply in Filter and in Find mode and use the same scope and the same regex switch as the main field. Positive conditions are highlighted like the main text; negative ones are not. The conditions are part of presets.

Design:

- Core `LogFilter.extraTerms: [SearchTerm]` with `public struct SearchTerm: Sendable, Equatable, Codable { public let text: String; public let isNegated: Bool }` (own file). `LogFilterEngine.makeQuery` becomes `makeQueries` (main plus each extra term, each `TextQuery?`); `matches` requires the main query (when present) and every positive term to match, and every negative term not to match, all with `filter.scope`. `isPassThrough` counts non-empty terms.
- Kit `LogFilterState.extraTerms: [SearchTerm]`, in `makeFilter`, `hasActiveFilters`, `hasPresetContent`, `clear()`, `FilterPreset` (decode as `[]` when missing), `findQuery` stays the main text; `FilterResult` for Find mode: the find matches are the records that satisfy the main query and the extra terms (change `FilterResult.compute` to pass the terms into `textMatches` or filter the candidates through the engine's `matches` with a filter that has only the text parts).
- `LogSession.setExtraTerms(_:)`, `addExtraTerm()`, `removeExtraTerm(at:)`, `updateExtraTerm(at:text:)` (debounced like `setSearchText`), `setExtraTermNegated(at:_:)`.
- `SearchTermsViewModel` (kit, per session, in `SessionViewModels.terms`): `items: [SearchTermItem]` (`id` = index, `text`, `isNegated`, `modeTitle`), `canAdd` (< 3), `add()`, `remove(id:)`, `setText(id:_:)`, `setNegated(id:_:)`, `isEmpty`. `SearchViewModel.addCondition()` forwards to the session.
- Views: `SearchTermsBar` (`Features/Toolbar`, emptiness check inside its body) with `SearchTermRow` (popup `Picker` with the two titles from the item, `TextField`, × button). `MainView.detail` adds it to the top inset `VStack` after the chips bar. `SearchBar` gets the `+` button with help "Add a condition".
- Chips: a chip per extra term is not shown (the bar shows them); `FilterChipsViewModel` ignores them.
- Highlighting: `LogFilterState.highlightQueries: [TextQuery]` (main plus positive terms); `MessageTextBuilder` and `EntryTextLayoutBuilder` take an array and union the ranges.
- README and CHANGELOG. Tests: core engine with positive and negative terms, kit `LogFilterStateTests`, `LogSessionTests`, `SearchTermsViewModelTests`, `FilterPresetTests` (round trip and old presets), `MessageTextBuilderTests` (two queries).

## 20. Column visibility, row density and font family

- Kit `Presentation/Models/LogTableColumn.swift`: `public enum LogTableColumn: String, CaseIterable, Codable, Sendable { case number, time, delta, level, tags, category, source, message }` with `displayName` in `Presentation/Display`. `canHide` is false for `message`.
- `AppSettings.hiddenColumns: Set<LogTableColumn>` (key `table.hiddenColumns`, JSON); it replaces `showDeltaColumn`: on first read, when the new key is missing and the old `table.showDelta` (check the real key) is false, start with `[.delta]`. Remove `showDeltaColumn` and its callers (`LogTableView`, the coordinator's `configure`, `SettingsView`, tests).
- `AppSettings.rowDensity: RowDensity` (`compact`, `comfortable`; key `table.density`, default comfortable; display names in `Presentation/Display`) and `fontFamily: FontFamily` (`monospaced`, `system`; key `table.fontFamily`, default monospaced).
- `SettingsViewModel`: `hiddenColumns`, `isColumnShown(_:)`, `toggleColumn(_:)`, `columnOptions: [ColumnOption]` (UI model: column, title, isOn, canHide), `rowDensity`, `fontFamily`, the option lists.
- App: `LogColumn` maps one to one to `LogTableColumn` (give `LogColumn` an `init(_ column: LogTableColumn)` and a `tableColumn` property). `LogTableView` passes `hiddenColumns`, `rowDensity`, `fontFamily`; the coordinator's `configure` sets `isHidden` per column, the vertical inset (`LogCellView.verticalInset` becomes an instance value from the density: 1 point compact, 3 comfortable) and rebuilds the `TextStyleSheet` with the font family (`LogFonts` gets a `family` parameter: `.monospacedSystemFont` or `.systemFont`). The row height follows the inset.
- Menus: View menu (`LogCommands`, the toolbar command group): a `Menu("Columns")` with a toggle per column (`Toggle(isOn:)` bound through the settings view model), then "Row Density" submenu with the two options, then "Font" submenu with the two families. `SettingsView`: the Table section gets the three controls (the delta toggle goes away).
- README (View menu) and CHANGELOG. Tests: `AppSettingsTests` (migration from the old delta key, persistence of the three), `SettingsViewModelTests`, `DisplayExtensionsTests`.

## 21. Log files of a connected iPhone

User-visible:

- The sidebar shows connected physical devices next to the simulators: a "Devices" section above the simulators. A device row shows the name, the iOS version and the connection ("USB" or "Wi-Fi"). Under it are the apps whose bundle ID starts with the bundle ID prefix setting, and their log files, exactly as for a simulator.
- A click on a device file opens it. Entries appear after the first copy (under 1 s for a 0.5 MB file over Wi-Fi). While the file grows on the device, new entries appear with a delay of about 1 to 3 seconds.
- Only development builds (installed from Xcode, `builtByDeveloper: true`) expose their container. Other apps are not listed.
- A device that is paired but not reachable (`tunnelState` is `unavailable`) is not shown.
- Delete actions (Move to Trash, Delete Older Files, Delete All Logs) are hidden for device files, apps and devices. The files on the device are never changed.
- Settings → General: "Show connected devices" (`devices.enabled`, default on). Off means LogReader never runs `devicectl`.
- Search inside files (group 17) skips a device file that has no local copy yet (`.skipped`).

How it works:

1. Everything goes through `/usr/bin/xcrun devicectl … --json-output <temp file> -q`. Samples of real output are in the session scratchpad (`devices.json`, `apps-all.json`, `files-parent.json`). Tests use fixtures with made-up names.
   - `list devices`: `result.devices[]` with `identifier`, `deviceProperties.name`, `deviceProperties.osVersionNumber`, `hardwareProperties.platform` (`iOS` only), `hardwareProperties.marketingName`, `connectionProperties.tunnelState` (`connected`, `disconnected`, `unavailable`), `connectionProperties.transportType` (`wired`, `localNetwork`; may be missing).
   - `device info apps --device <id>`: `result.apps[]` with `bundleIdentifier`, `name`, `builtByDeveloper`.
   - `device info files --device <id> --domain-type appDataContainer --domain-identifier <bundle> --subdirectory "Library/Application Support"`: a recursive list, `result.files[]` with `relativePath`, `metadata.size`, `metadata.lastModDate` (ISO 8601, UTC), `resources.isDirectory`. Keep the entries whose `relativePath` starts with `Logs/` and ends with `.txt`. Do not pass `--subdirectory ".../Logs"`: with it, devicectl cuts the first characters of every name (devicectl bug, Xcode 26.6). This workaround gets a one-line comment.
   - `device copy from --device <id> --domain-type appDataContainer --domain-identifier <bundle> --source "Library/Application Support/Logs/<name>" --destination <local file>`: copies the whole file. There is no partial read.
2. Core (`Discovery`): `SimulatorDevice` gets `kind: DeviceKind` (`.simulator`, `.physical(DeviceTransport)`), `DeviceTransport` (`.usb`, `.network`, `.unknown`). `SimulatorLogScanner` sets `.simulator`. Pure decoders for the three JSON shapes (`DevicectlDeviceList`, `DevicectlAppList`, `DevicectlFileList` or similar, one type per file, `Decodable`, tested with fixtures). The file name `log-2026.11.07-10:34:52.txt` gives `createdAt` in local time; `lastModDate` is the fallback.
3. Kit `Infrastructure`:
   - `DevicectlRunner`: runs `xcrun devicectl` with `Process` off the main actor, writes JSON to a temp file, reads and deletes it. Timeout 15 s, then `terminate()`. Missing `xcrun` or a non-zero exit gives an error, never a crash. Behind a small internal protocol (`DevicectlCommandRunning` or similar) so tests use a fake that returns fixture JSON.
   - `PhysicalDeviceDiscovery`: conforms to `LogDiscovery`. Returns `[SimulatorDevice]` with `kind: .physical(...)`. `folderURL` is the cache folder of the device, `~/Library/Caches/LogReader/Devices/<udid>`. `AppLogContainer.logsURL` is `<cache>/<udid>/<bundleID>`, `LogFileItem.url` is `<logsURL>/<remote file name>`, `size` is the remote size. The local file may not exist yet. One instance is shared by all windows, so it caches its last result for 5 s behind a lock and never runs two scans at once.
   - `CompositeLogDiscovery`: conforms to `LogDiscovery`, returns the physical devices first, then the simulators. When `devices.enabled` is off it skips the physical part. Read the setting through an injected closure or a `Sendable` flag the composition root keeps in sync; do not read `UserDefaults` from a background task.
   - `DeviceFileMirror`: copies one remote file into its cache path. Every 1.5 s: list the files (one `info files` call), and when the remote size changed since the last copy, copy into a temp file next to the cache file. If the temp file is larger than the cache file, append only the new bytes to the cache file (`FileHandle`, seek to end). If it is smaller, or the remote file is gone and a new one exists, replace the cache content (truncate and write), so the tailer reports `.reset`. A failed call keeps the cache and retries on the next tick.
   - `DeviceLogSource`: conforms to `LogSource`. Starts the mirror, waits for the first copy, then forwards the events of a `LogFileTailer` on the cache file. Stops the mirror when the stream ends.
   - `RoutingLogSourceFactory` (or extend `FileTailerSourceFactory`): a URL inside the device cache root gets a `DeviceLogSource`, every other URL a `LogFileTailer`. It needs to map a cache URL back to `udid`, `bundleID` and the remote name: the path layout above is enough, no extra state.
4. Kit `Application` and `Presentation`:
   - `AppSettings.showsConnectedDevices` (`devices.enabled`, default true), `SettingsViewModel` toggle.
   - `SidebarViewModel`: device sections, subtitle "iOS 27.0.1 · Wi-Fi" / "USB" from a formatter, symbol name for the row (`iphone` for physical devices), `canDelete` false for physical devices, apps and files. "Booted only" keeps connected devices.
   - `DeleteLogFiles` and the sidebar menus: no delete entries for physical items.
5. App: `SidebarView` shows the section and the subtitle. `AppDependencies` builds `DevicectlRunner`, `PhysicalDeviceDiscovery`, `CompositeLogDiscovery` and the routing factory. `Scripts/check-layers.sh` gets the new adapter names in both adapter lists.
6. Tests: decoders with fixtures, `PhysicalDeviceDiscovery` with a fake runner (only iOS, only reachable devices, only `builtByDeveloper` apps with the prefix, only `Logs/*.txt`, cache paths, 5 s cache), `DeviceFileMirror` append and replace with a fake runner that writes files, `CompositeLogDiscovery` order and the setting, sidebar view model items and `canDelete`.
7. Docs: `docs/architecture.md` (data flow for device files, the window model line about discovery), `README.md` (devices, the setting, "development builds only"), `CHANGELOG.md`.

Out of scope: deleting files on the device, devices other than iOS, a status bar message for an unreachable device.

## 22. Self-update from the local `main` branch

The app is built from source on this Mac. `Scripts/install.sh` runs once by hand. After that the running app finds new commits in `main` and installs them on a click. This replaces the git hooks of `Scripts/auto-install.sh`.

The source of updates is the local working copy, not a remote (`/Users/.../LogReader`, the folder `install.sh` was first run from). The updater never builds in the working copy: it has its own clone, so local edits, other branches and a running Xcode build do not get in the way.

User-visible:

- At the bottom of the sidebar, a small button that is always visible when it has a state:
  - no update: hidden;
  - available: "Update available · 3" with an `arrow.down.circle` symbol; a click opens a popover with the commit subjects (short hash and subject) and "Update Now";
  - running: a small spinner, the phase and the time since the start: "Getting changes · 0:03", "Building · 1:20", "Installing · 2:05"; no click;
  - failed: "Update failed" in the warning color; a click opens a popover with the end of `update.log` (last 200 lines, monospaced, scrollable) and "Try Again";
  - after a successful update: "Updated to 4bf0b5d" for one launch, with a close button.
- App menu: "Check for Updates…" runs the check now. When there is nothing new, the button shows "Up to date" for 5 seconds.
- The app is closed only for the few seconds when the new bundle replaces the old one. Then it opens again.
- A development build run from Xcode never checks (no `installed.json`, or the running bundle is not `/Applications/LogReader.app`).

Files (`~/Library/Application Support/LogReader/`):

| Path | Job |
|---|---|
| `source/` | The build clone. `git clone --branch main <working copy path> source`. Its `origin` is the working copy. Its `DerivedData/` (ignored by git) keeps builds incremental. |
| `update/installed.json` | `{"commit": "<full sha>", "branch": "main", "source": "<clone path>", "installedAt": "<ISO 8601>"}`. Written by `install.sh` after a successful install. |
| `update/status.json` | `{"phase": "fetching" \| "building" \| "installing" \| "done" \| "failed", "startedAt": "<ISO 8601>", "commit": "<sha or null>", "message": "<text or null>"}`. Written by the scripts with a temp file and `mv`. |
| `update/update.log` | Full output of the last update. |
| `update/update.lock` | The pid of the running `update.sh`. |

Scripts:

1. `Scripts/install.sh` (what it already does, plus):
   - When the clone does not exist and the script runs from a working copy (not from the clone), `git clone --branch main "$ROOT" "<clone>"`.
   - When `UPDATE_STATUS_FILE` is set: phase `building` before the build, `installing` before quit and copy, `done` with the commit at the end.
   - After the copy: write `installed.json` with `git -C "$ROOT" rev-parse HEAD` and `source` = the clone path.
   - Quit, copy, sign and `open` stay as they are now (`quit.sh`, staged `.new` bundle, `sign-identity`).
2. `Scripts/update.sh` (run from the clone): takes the lock (exits when another live pid holds it), writes `fetching`, `git -C "$SOURCE" fetch --quiet origin main && git -C "$SOURCE" reset --hard origin/main`, then runs `"$SOURCE/Scripts/install.sh"` with `UPDATE_STATUS_FILE` exported. Any failure writes `failed` with a short message ("Could not get the changes", "The build failed. See the log") and exits 1. `startedAt` stays the same through the phases. Removes the lock on exit.
3. Delete `Scripts/auto-install.sh` and `Scripts/install-hooks.sh`. Remove the hook text from `CLAUDE.md` and `README.md`. The orchestrator deletes `.git/hooks/post-commit` and `.git/hooks/post-merge` itself; the implementer does not touch `.git`.

The check (once at launch, then every 5 minutes, and from the menu):

```sh
/usr/bin/git -C <source> fetch --quiet origin main
/usr/bin/git -C <source> merge-base --is-ancestor <installed> origin/main
/usr/bin/git -C <source> log --format=%h%x1f%s <installed>..origin/main
```

- Skip when `installed.json` is missing, when the app does not run from `/Applications/LogReader.app`, or while an update runs.
- `merge-base` fails (the installed commit is not in `main`): no update.
- Full paths for git and zsh. Run every command off the main actor with a timeout (30 s), like `DevicectlRunner`.

Start: `/bin/zsh -c '/usr/bin/nohup "<source>/Scripts/update.sh" > "<dir>/update.log" 2>&1 &'`. The shell exits at once; launchd adopts the script, so it survives the app quitting.

Progress: while running, read `status.json` every second. After launch: `done` with the commit equal to `installed.json` gives "Updated to <short hash>" once, then `status.json` is deleted. `failed` gives the failed state. `fetching`, `building` or `installing` without a live pid in the lock means the update died: failed with "The update stopped".

Code shape:

- Kit port `AppUpdater` (`Application/Ports`): `installed() -> InstalledBuild?`, `check(installed:) throws -> [UpdateCommit]`, `start() throws`, `status() -> UpdateStatus?`, `clearStatus()`, `log() -> String`, `isUpdateRunning() -> Bool`. Value types in `Application/Update` (or similar): `InstalledBuild`, `UpdateCommit` (`shortHash`, `subject`), `UpdateStatus`, `UpdatePhase`. JSON decoding of the two files is pure and tested.
- Kit adapter `GitAppUpdater` in `Infrastructure` (Foundation `Process`, `FileManager`). Add it to both adapter lists in `Scripts/check-layers.sh`.
- Kit `UpdateStore` (`@MainActor @Observable`, one per process, owned by `AppDependencies`, shared by every window): state `idle`, `upToDate`, `available([UpdateCommit])`, `running(UpdatePhase, startedAt)`, `failed(message)`, `updated(shortHash)`. Owns the 5 minute loop and the 1 second status loop. The interval, the status interval and the clock (`() -> Date`) are injected, so tests do not wait.
- Kit `UpdateViewModel` (Presentation): button title, symbol, style token, elapsed text from a formatter (`m:ss`), popover items, actions `updateNow()`, `tryAgain()`, `checkNow()`, `dismissUpdated()`.
- App: `Features/Sidebar/UpdateButton.swift` (+ popover views), the menu item in `LogCommands` or the app commands, wiring in `AppDependencies` and the sidebar.
- Tests with a `FakeAppUpdater`: every state change after each status, the comparison rules (behind, equal, not in main), the "done after launch" message, a dead update, "Up to date" after a manual check, the elapsed text.
- Docs: `README.md` (how to install once, how updates work, where the files are), `CLAUDE.md` (build section: install once, no hooks), `docs/architecture.md`, `CHANGELOG.md`.

## 23. Log profiles: the log format is configured per project

Decision: `docs/adr/0006-log-profiles.md`. Schema and the built-in JSON format: `docs/log-format.md`. Branch `generic-log-format`.

Goal: no knowledge of one app's log format in the code. Everything that was fixed (folder, file name, bundle ID prefix, header line grammar, level codes, colors, columns, facets, search scopes, export keys, source file extension, editor command) comes from a profile file in the project, or from the built-in JSON lines profile.

Stages. Each stage ends with the five checks green and one commit on the branch.

1. **Core: profile model and parser.** `LogProfile` (Codable, Sendable, validated) with `discovery`, `framing`, `entry`, `timestamp`, `levels`, `attributes`, `fields`, `source`. `LogLevel` becomes an index into the level list; `LogRecord` gets `attributes: [[String]]`. `LogEntryGrammar` compiles the profile: `trailing` and `leading` token lists, `regex`, `json`. `TimestampParser` compiles a pattern into byte positions. `LogIndexer(profile:)`, `LogFileTailer(url:profile:...)`, `LogEntryDetails.parse(_:record:profile:)`, `FacetCounts(profile:)`. `FacetColumn`, `FacetSelection`, `SearchScope` name levels and attributes by id. Discovery takes `[DiscoveryRule]`. Tests: the `text-trailing.json` example profile reproduces every old parser test; new tests for leading, regex and JSON grammars; the PERF test runs for every grammar kind.
2. **Kit: profiles in the application layer.** `AppSettings.projectRoots` (migrates `source.projectRoot`), `ProfileRegistry` (loads every `.logreader/profile.json`, reloads when the file changes, keeps errors), `LogProfileLoader` port and the Foundation adapter, `LogSessionFactory.makeSession(url:profile:...)`, `Workspace` chooses the profile, `SidebarStore` scans with the discovery rules of every profile, `OpenSource` uses the project folder and editor of the session's profile, `EntryJSONEncoder` writes attribute ids, `LogTableColumn` with attribute columns, presets and recent sets with the new encoding and the old one readable.
3. **Kit: presentation.** Level options, facet popovers, filter chips, search scope options, column options, row items (`levelStyle`, attribute values), context menu entries and the inspector header built from the profile. `TextStyle.message(LevelStyle?)`.
4. **App.** `LevelColors` by style token, dynamic table columns, Settings → Projects (add or remove a folder, loaded profiles and errors, Reload, Create Example Profile), `AppDependencies` wiring.
5. **Docs and the example profile.** `docs/log-format.md` (profile schema, built-in JSON format, limits), `docs/profiles/text-trailing.json` and `docs/profiles/text-leading.json`, `docs/architecture.md`, `README.md`, `CLAUDE.md`, `CHANGELOG.md`; `.logreader/profile.json` in the working copy of the owner's app with a local git exclude.

Cuts and fixed parts (to confirm with the user at the end): the export format stays the self-describing header + separator format; simulators and iPhones are the only discovery sources; a manual "parse as" choice for an opened file is not built; the JSON mode searches the whole line (keys included); a continuation line that arrives in a later read starts a new entry.
