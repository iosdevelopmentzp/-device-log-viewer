# Architecture

## Modules and layers

Three modules. The direction is fixed: app → kit → core. Decisions: `docs/adr/0004-layered-architecture.md`, `docs/adr/0005-dependency-injection.md`. Rules the compiler cannot check are in `.claude/rules/layers.md` and enforced by `Scripts/check-layers.sh`.

1. **`LogReaderCore`** (package, Foundation only). The log profile (`LogProfile` and its rules, `docs/log-format.md`), the byte parser compiled from a profile (`LogEntryGrammar`), `LogContent`, the filter engine, the tailer behind the `LogSource` protocol, simulator discovery, the decoders for the JSON output of `devicectl` (`DevicectlDeviceList`, `DevicectlAppList`, `DevicectlFileList`), and pure helpers (`FacetCounts`, `FacetSelection`, `SortedIndices`). Tested with `swift test`.
2. **`LogReaderKit`** (package, Foundation + Observation + core). Three folders:
   - `Application`: ports (protocols for the pasteboard, dialogs, Finder, the Trash, file writing, file content search, appearance, Dock attention, key-value storage, bookmarks, discovery, sources, app updates, profile loading), `ProfileRegistry` (the project folders and their profiles, one per process), `AppSettings`, `LogSession` (one open file), `Workspace` and `SidebarStore` (one window), `UpdateStore` (one per process), use cases (`CopyEntries`, `FileActions`, `DeleteLogFiles`, `ExportEntries`), pure policies (`NewestFilePolicy`, `LogCleanupPolicy`).
   - `Infrastructure`: adapters that need only Foundation or the core (`UserDefaults`, `LogFileTailer`, `SimulatorLogScanner`, `FileManager`, `FileLogProfileLoader`, `ProcessSourceOpener`), and the iPhone adapters: `DevicectlRunner` (runs `xcrun devicectl` with `Process`), `PhysicalDeviceDiscovery`, `CompositeLogDiscovery`, `DeviceFileMirror`, `DeviceLogSource`, `RoutingLogSourceFactory`. The self-update adapter `GitAppUpdater` runs `git` and `Scripts/update.sh` with `Process` and reads the update files.
   - `Presentation`: view models (one per screen, popover or sheet), UI models (`LogRowItem`, `StyledText`, `SidebarFileItem`, ...), formatters, display names.
   Tested with `swift test` and fakes for every port.
3. **`LogReader`** (app target, SwiftUI + AppKit). Views under `Features`, AppKit adapters for the ports under `Platform`, colors and fonts and the `TextStyle` → attributes mapping under `Theme`, the entry point and the composition root (`AppDependencies`) under `App`. No unit tests; keep it thin.

A view talks to one view model. A view model reads a session or a store and calls its methods. A session depends on ports and core types. The composition root is the only place that pairs a port with an adapter.

## Log profiles

```
Settings → Projects: [project folder]
  │  every 3 s: modification date of <folder>/.logreader/profile.json
  ▼
ProfileRegistry (kit, one per process)   LogProfileLoader port → FileLogProfileLoader; keeps profile or error per project
  │  discoveryRules → SidebarStore.start(rules:)         profile(for: url, bundleID:) → LogSessionFactory.makeSession(url:profile:)
  ▼
LogSession.content = LogContent(profile:)   the profile travels with the content snapshot into the filter task
  │  LogIndexer(profile:) → LogEntryGrammar (compiled once per session)
  ▼
LogRecord.level = index into profile.levels; LogRecord.attributes[i] = value of profile.attributes[i]
```

`Workspace` watches `ProfileRegistry.generation`: a changed profile restarts the discovery and opens the current file again with the new profile. The theme maps `LevelStyle` tokens and the `alerts` / `highlightsRow` / `colorsMessage` flags; no file in the app names a level. Facets, search scopes, columns, presets and recent filters name levels and attributes by their string id, so saved values survive a profile change.

## Data flow

```
log file on disk
  │  DispatchSource (.write/.extend/.delete/.rename) + 1 s poll
  ▼
LogFileTailer (LogSource)   reads only the new bytes; detects truncate and file replace
  │  LogIndexer(profile:).consume(bytes) → LogBatch (complete entries only)
  │  AsyncStream<LogSourceEvent>: .batch / .reset / .missing
  ▼
LogSession.handle          LogContent.append(batch); FacetCounts.add(records)
  │  FilterResult.compute on the new records only (pass-through or at most 5 000 records)
  ▼
visible: [Int]             indexes of the records that pass the filter
  │  LogRowsObserver.handle(.inserted(range))      (synchronous)
  ▼
LogTablePresenter          maps records to LogRowItem on demand
  │  LogTableUpdateReceiver.apply(.inserted(range)) (synchronous)
  ▼
LogTableCoordinator        insertRows; scroll to the end in Follow mode
```

A filter change runs `FilterResult.compute` through `LogFilterRunner` in a detached task with a snapshot of `LogContent`. A newer change cancels the older run. Text changes are debounced (150 ms); other changes run at once. When the result arrives, the records that were added during the work are filtered too.

When Collapse Repeated Entries is on, `LogTablePresenter` keeps a `RowCollapser` between the session and the table. `LogSession.visible` does not change. The collapser groups consecutive visible records with the same message and level, and maps table rows to record indexes and back. The presenter translates every `LogRowsEvent`: `.inserted` can extend the last group (then it sends `.refreshRows`), and `.select` opens a collapsed group before it selects the row. Bookmarks, Find and Copy still work on record indexes.

Row updates reach `NSTableView` synchronously through two weak observer protocols, because the table's row count must match the data source at the moment of `insertRows`. Everything else uses `@Observable` tracking.

### Files of a connected iPhone

```
iPhone (development build)
  │  xcrun devicectl device info files   every 1.5 s, one call
  │  xcrun devicectl device copy from    when the remote size changed
  ▼
DeviceFileMirror           copies into a hidden part file next to the cache file
  │  larger: append only the new bytes (same file)
  │  smaller, or gone and back: rename the part file over the cache file (new inode)
  ▼
~/Library/Caches/LogReader/Devices/<device id>/<bundle ID>/<file name>
  │
  ▼
LogFileTailer              a new inode or a smaller file gives .reset
  ▼
DeviceLogSource            starts the mirror, waits for the first copy, then forwards the tailer events
```

`RoutingLogSourceFactory` gives a `DeviceLogSource` to every URL in the device cache folder and a `LogFileTailer` to every other URL. The path holds everything it needs: device id, bundle ID and remote file name. `PhysicalDeviceDiscovery` builds the same paths, so the session, the presenters and the views do not know that a file comes from a phone. One `DevicectlRunner` waits at most 15 s for a command, then terminates it. A failed call keeps the last result: the discovery shows the previous device, and the mirror keeps the cache file and tries again on the next tick. Every `devicectl` call runs on a background queue, never on the main actor.

### Self-update

```
working copy (main)            Scripts/install.sh once: clone, build, install, installed.json
  │  git fetch origin main      (origin of the clone = the working copy; there is no remote)
  ▼
~/Library/Application Support/LogReader/source        build clone, own DerivedData
  │  merge-base --is-ancestor <installed> origin/main; log <installed>..origin/main
  ▼
GitAppUpdater (AppUpdater) ──► UpdateStore ──► UpdateViewModel ──► UpdateButton (sidebar)
  │  "Update Now": /bin/zsh -c 'nohup source/Scripts/update.sh > update.log &'
  ▼
Scripts/update.sh          lock → fetching → reset --hard origin/main → install.sh (building → installing → done)
  │  writes update/status.json (temp file + mv); install.sh quits the app, replaces the bundle, opens it
  ▼
UpdateStore                reads status.json every second while an update runs
```

- `UpdateStore` (kit, `Application/Update`) is one per process. `AppDependencies` builds it and calls `start()`; every window shows the same `UpdateViewModel` through the SwiftUI environment, and the menu item LogReader → Check for Updates… calls the same model.
- At launch the store reads `installed.json`, `status.json` and the lock in one detached task. No `installed.json`, or a bundle that is not `/Applications/LogReader.app`, means a development build: no check, no button. `done` with the installed commit gives "Updated to <short hash>" and deletes `status.json`. `failed` gives the failed state. A running phase without a live process in `update.lock` means the update died.
- The check runs at launch and then every 5 minutes, never while an update runs. A failed `fetch` keeps the current state. When `merge-base` fails (the installed commit is not in `main`), there is no update.
- While an update runs, the store reads the lock and then `status.json` every second (in this order, so a script that writes its last status and exits is not taken for a dead one). For the first 10 seconds after "Update Now", a missing status or lock is not an error, because the detached script needs a moment to start.
- Every `git` and `zsh` call runs off the main actor with a 30 s timeout. The interval, the status interval, the "Up to date" time and the clock are injected, so the tests do not wait.

## Storage model

- `LogContent.chunks: [Data]` holds the bytes. Every chunk contains only complete entries, so an entry never crosses two chunks.
- `LogRecord` keeps the chunk number, the start and the length of the entry, plus the parsed header: level (an index into the profile levels), timestamp, one `AttributeValue` per profile attribute, a short message (up to 1 KB) and a preview of the first field.
- The full text of an entry is decoded only when the inspector or a copy needs it.
- `LogRecord.offset` is the byte offset in the file. Bookmarks use it, because the file only grows. After a truncate, the bookmarks of the file are cleared.

## Window model

- Several windows: `LogReaderApp` has one `WindowGroup(id: "main", for: URL.self)`. Each window gets its own `MainViewModel` from `AppDependencies.makeMainViewModel()`, so each window has its own `Workspace`, sidebar scan and session. A window opened with a URL opens that file in `MainView.task` through `MainViewModel.openExternal`. To open a new window, `MainViewModel.openInNewWindow(_:)` sets `windowRequest` (`WindowRequest`: a new `id` each time and an optional URL). `MainView` watches it and calls `openWindow(id: "main", value: url)`, or `openWindow(id: "main")` without a URL. The sidebar asks for a new window through the weak `SidebarWindowObserver`, which `MainViewModel` implements. Native tabs come from `NSWindow.allowsAutomaticWindowTabbing` (`Platform/WindowTabbing.swift`).
- `AppDependencies` (app): built once per process. Holds `AppSettings`, `SettingsViewModel`, the adapters and the factories. `makeMainViewModel()` builds the graph of one window.
- `MainViewModel` (kit): one per window. Owns `SidebarViewModel`, the window flags (inspector, sheet, focus requests) and the per-session view models (`SessionViewModels`: table presenter, search, inspector, filter menu). Rebuilds them when `Workspace` opens another file. Also owns one `ErrorAlertController`. It watches the current session through `LogAppendObserver`. When an error arrives while the app is in the background, it bounces the Dock icon and sets the Dock badge through the `AppAttention` port.
- `Workspace` (kit): one per window. Owns `SidebarStore` and the current `LogSession`. Opens the newest file of the same app when a new session starts (`NewestFilePolicy`, when the setting is on).
- `SidebarStore` (kit): scans every 3 seconds in a background task through the `LogDiscovery` port. The live port is `CompositeLogDiscovery`: connected iPhones first (`PhysicalDeviceDiscovery`), then the simulators (`SimulatorLogDiscovery`). It skips the iPhones when the setting `devices.enabled` is off. Background tasks cannot read `AppSettings`, so the setting also lives in `AppSettings.connectedDevicesFlag`, a `SharedFlag` that the setting updates in `didSet`. `PhysicalDeviceDiscovery` is shared by all windows: it keeps its last result for 5 seconds behind a lock, so two windows never run two scans at once.
- `SidebarContentSearch` (kit): one per sidebar, owned by `SidebarViewModel`. Waits 400 ms after the last change of the text, then counts the matches in every shown file in one detached task through the `FileContentSearcher` port. A new text cancels the running search. `SidebarFilter` keeps only the files with matches.
- `LogSession` (kit): one open file. Owns the source, the content, the facet counts, the filter state, the visible indexes, the find matches, the selection, the bookmarks and Follow mode.
- `UpdateStore` (kit): one per process, shared by every window. See "Self-update" above.
- `AppSettings` (kit): global settings behind the `KeyValueStore` port, shared by every window. Views reach them through `SettingsViewModel` in the environment.
- `SearchHistory` and `FilterHistory` (kit): pure values in `AppSettings`, stored as JSON under `search.recent` and `filters.recent`. `SearchViewModel.commitSearch()` adds a search. `FilterHistoryRecorder` (one per session, owned by `MainViewModel`) watches `LogSession.filterState` and adds the facet part 3 seconds after the last change.
- Menu commands find the active window with `@FocusedValue(\.mainViewModel)`.

## Performance targets

Measured with `PerformanceTests` (50 MB, about 90 000 to 100 000 entries, release build, Apple Silicon). The test runs once per entry grammar kind.

| Step | Target | trailing (`text-trailing.json`) | leading | regex | JSON lines |
|---|---|---|---|---|---|
| Index a 50 MB file | < 1 s | 90–110 ms | 80–130 ms | 250–320 ms | 220 ms |
| ASCII search over all entries | < 300 ms | 9 ms | 11 ms | 13 ms | 11 ms |
| Non-ASCII search (for example Cyrillic) | < 300 ms | 8 ms | 8 ms | 8 ms | 9 ms |
| Regular expression search (`\bcyrillic\b`) | < 2 s | 160 ms | 160 ms | 156 ms | 147 ms |
| Level + attribute facet filter | — | 1.4 ms | 1.4 ms | 1.3 ms | 1.0 ms |

Measured on 2026-11-15. The `regex` grammar decodes every line to a `String` for `NSRegularExpression`; the JSON grammar scans the bytes itself and never calls `JSONSerialization` while indexing.

Non-ASCII search skips entries that have no non-ASCII bytes. Only the remaining entries are decoded to `String`. A regular expression search decodes every entry to `String` and runs `NSRegularExpression` on it, so it is slower than a plain search.

## How to add a new log source

Example: the live `os_log` stream. Connected iPhones (see "Files of a connected iPhone" above) follow these steps.

1. Add a type in the core that conforms to `LogSource` (events: `.batch`, `.reset`, `.missing`). If the data is not a local file, copy it to a local cache and reuse `LogFileTailer`.
2. Add a `LogDiscovery` adapter in the kit's `Infrastructure` that returns the devices and files of the new source, and a `LogSourceFactory` that builds the source for a file.
3. Wire both in `AppDependencies`. The session, the presenters and the views do not change.
4. Show the new source in `SidebarViewModel` as new items, and in `SidebarView` as a new section.
