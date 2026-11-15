# LogReader

LogReader is a macOS app for reading the log files that an iOS app writes. It finds the files in every iOS simulator and on connected iPhones, shows new entries live, and gives search, filters, bookmarks and copy.

The log format is not fixed: each project describes its logs in `.logreader/profile.json` (a log profile, `docs/log-format.md`, ADR 0006). A project that writes JSON lines needs no profile. The code holds no knowledge of one app's format.

The Xcode console cuts long messages (about 32 KB, or about 1 KB after "attach to process"). The log files have no such limit. This app exists to read them comfortably.

## Build and test

```bash
# Core package: parser, tailer, filters, simulator discovery
cd Packages/LogReaderCore && swift test

# Kit package: ports, sessions, stores, use cases, view models, formatters
cd Packages/LogReaderKit && swift test

# Performance check on a generated 50 MB file (prints PERF line)
cd Packages/LogReaderCore && LOGREADER_PERF=1 swift test -c release --filter PerformanceTests

# App
xcodebuild -project LogReader.xcodeproj -scheme LogReader -destination 'platform=macOS' build

# Layer rules the compiler cannot check
Scripts/check-layers.sh

# No owner project, company, host or person named in the repository (see .claude/rules/anonymity.md)
Scripts/check-anonymous.sh

# Install a Release build in /Applications once (quits the running app; only when the user asks)
Scripts/install.sh
```

- Install once with `Scripts/install.sh`. After that, updates come from the update button in the app: it builds `main` of this working copy in its own clone (`~/Library/Application Support/LogReader/source`) with `Scripts/update.sh`. See "Install in /Applications" in `README.md`.
- An agent never runs `Scripts/install.sh` or `Scripts/update.sh` unless the user asks. Both quit the running app.

- macOS 26.4, Xcode 26.6. App target: Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Both packages: Swift 6 language mode. No UI frameworks.
- App Sandbox is off on purpose. See `docs/adr/0002-no-sandbox.md`.

## Structure

Three modules. Direction: app → kit → core. See `docs/adr/0004-layered-architecture.md` and `.claude/rules/layers.md`.

| Path | Role |
|---|---|
| `Packages/LogReaderCore/.../Profile` | `LogProfile` and its rules: `DiscoveryRule`, `FramingRule`, `EntryRule`, `EntryToken`, `TimestampRule`, `LevelRule`, `AttributeRule`, `FieldsRule`, `SourceRule`; `LogProfile.jsonLines` (built-in) |
| `.../Domain` | `LogLevel` (index into the profile levels), `LogRecord` (+ `AttributeValue`), `LogBatch`, `LogFileFormat`, `FacetColumn` |
| `.../Parsing` | `LogIndexer` (bytes → batches), `LogRecordBuilder`, `LogEntryGrammar` (`TokenGrammar`, `RegexGrammar`, `JSONEntryParser`), `TimeValueParser`, `LevelMatcher`, `LogEntryDetails`, `LogTextMetrics` |
| `.../Storage` | `LogContent` (chunks of bytes + records) |
| `.../Tailing` | `LogSource` protocol, `LogFileTailer` (live read of a growing file) |
| `.../Filtering` | `LogFilter`, `LogFilterEngine`, `FacetFilter`, `FacetSelection`, `FacetCounts`, `TextQuery` |
| `.../Discovery` | `SimulatorLogScanner` and its item types |
| `.../Support` | `SortedIndices` |
| `Packages/LogReaderKit/.../Application/Ports` | Protocols for the outside world: pasteboard, dialogs, Finder, appearance, storage, discovery, sources, profile loading |
| `.../Application/Profiles` | `ProfileRegistry` (the project folders and their profiles), `ProjectProfile`, `ExampleProfileText` |
| `.../Application/Settings` | `AppSettings`, `LogTableColumn` |
| `.../Application/Session` | `LogSession` (one open file), `LogFilterState`, `LogFilterRunner` |
| `.../Application/Workspace` | `Workspace` (one window), `SidebarStore`, `NewestFilePolicy` |
| `.../Application/UseCases` | `CopyEntries`, `FileActions` |
| `.../Application/Update` | `UpdateStore` (self-update state, one per process), `InstalledBuild`, `UpdateStatus`, `UpdateDecoder` |
| `.../Infrastructure` | Adapters that need only Foundation or the core |
| `.../Presentation/Models` | UI models: `LogRowItem`, `StyledText`, `SidebarFileItem`, ... |
| `.../Presentation/Formatting` | Time, delta, size, file title, message and entry text builders |
| `.../Presentation/Display` | `displayName` extensions |
| `.../Presentation/ViewModels` | One view model per screen, popover or sheet |
| `LogReader/App` | Entry, menu commands, `AppDependencies` (composition root) |
| `LogReader/Platform` | AppKit adapters for the ports |
| `LogReader/Theme` | Colors, fonts, `TextStyle` → attributes |
| `LogReader/Features` | Views: `Main`, `Toolbar`, `Sidebar`, `LogTable` (AppKit `NSTableView`), `Inspector`, `Settings` |
| `docs/` | Profile schema and the built-in format, example profiles (`docs/profiles/`), architecture, decisions (ADR), roadmap, refactoring plan |

Read `docs/architecture.md` before a bigger change, and `docs/log-format.md` before you touch the parser or a profile rule. Never add knowledge of one app's log format to the code; it belongs in a profile file. `docs/refactoring-plan.md` is the specification of the current layering work.

## Rules

@.claude/rules/layers.md
@.claude/rules/presentation.md
@.claude/rules/files.md
@.claude/rules/swift-style.md
@.claude/rules/testing.md
@.claude/rules/anonymity.md

## Skills

- `/add-feature`: the workflow for a new feature, layer by layer.
- `/layer-templates`: the shape of every kind of file.
- `/check-layers`: run the checks and review a diff against the rules.

## Change log and docs

Every change updates `CHANGELOG.md` (section `Unreleased`). When behavior, structure or the log format changes, update the matching file in `docs/`. Commit only when the user asks.
