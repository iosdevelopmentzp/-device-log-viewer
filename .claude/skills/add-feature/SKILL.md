---
name: add-feature
description: Step-by-step workflow for a new feature or a behavior change in LogReader. Use when the user asks to add, change or extend something the app does (a filter, a menu item, a setting, a new log source, an export). Picks the layer for each part, lists the files to create, and ends with the required checks.
---

# Add a feature

Read `.claude/rules/layers.md` and `.claude/rules/presentation.md` first. Then follow the steps in order. Skip a step only when the feature does not touch that layer.

## 1. Split the feature by layer

Answer these questions and write the answers down before you create a file.

| Question | If yes | Folder |
|---|---|---|
| Does the log format, the parser, the filter engine or the tailer change? | core change | `Packages/LogReaderCore/Sources/LogReaderCore/<Area>` |
| Is there a pure decision or a pure computation (sorting, matching, naming, counting)? | core or kit `enum` with static functions | `Core/Support`, `Core/Filtering` or `Kit/Application/<Area>` |
| Does the app need something from outside the process (file dialog, clipboard, Finder, a tool, a stored value)? | a port and an adapter | `Kit/Application/Ports` + `LogReader/Platform` (AppKit) or `Kit/Infrastructure` (Foundation, core) |
| Does state live longer than a view (per app, per window, per open file)? | a store, `AppSettings`, `Workspace`, `SidebarStore` or `LogSession` | `Kit/Application/<Area>` |
| Does one action touch two or more ports or stores? | a use case | `Kit/Application/UseCases` |
| Does the screen show new strings, numbers, symbols, styles or lists? | UI model, formatter, display name | `Kit/Presentation/Models`, `Formatting`, `Display` |
| Does a screen, popover or sheet need new state or actions? | view model method or property | `Kit/Presentation/ViewModels` |
| Does the user see something new? | view | `LogReader/Features/<Area>` |
| Is there a shortcut or menu item? | `LogCommands` + a `MainViewModel` method | `LogReader/App` |
| Is there a new setting? | `AppSettings` property + key, `SettingsViewModel` pass-through, `SettingsView` row | three files |

## 2. Create the files, bottom up

Core → kit application → kit presentation → app. Use `/layer-templates` for the shape of each file. One type per file (`.claude/rules/files.md`).

For each new port:

1. `Kit/Application/Ports/<Name>.swift` protocol.
2. Adapter in `LogReader/Platform/<Impl>.swift` or `Kit/Infrastructure/<Impl>.swift`.
3. `Kit/Tests/LogReaderKitTests/Fakes/Fake<Name>.swift`.
4. One line in `LogReader/App/AppDependencies.swift`.

For each new view model property or method: a test in `Kit/Tests/LogReaderKitTests/<ViewModel>Tests.swift`.

## 3. Wire the view

- The view takes its view model in `init`, or a UI model value and closures for a small subview.
- Bindings: `@Bindable var model`, bind to a `var` with `get` and `set` on the view model.
- No formatting, no `switch` on domain values, no port calls in the view.
- Theme tokens (`TextStyle`, `LogLevel` colors) are mapped in `LogReader/Theme` only.

## 4. Checks

```bash
cd Packages/LogReaderCore && swift test
cd Packages/LogReaderKit && swift test
xcodebuild -project LogReader.xcodeproj -scheme LogReader -destination 'platform=macOS' build
Scripts/check-layers.sh
```

If `Parsing` or `Filtering` changed: `LOGREADER_PERF=1 swift test -c release --filter PerformanceTests` and update the table in `docs/architecture.md`.

## 5. Docs

- `CHANGELOG.md`, section `Unreleased`, one line per user-visible change.
- `README.md` when a shortcut, a menu or a setting changes.
- `docs/log-format.md` when the parser changes.
- `docs/architecture.md` when a layer, a store or the data flow changes.
- A new ADR in `docs/adr/` when a decision in an existing ADR changes.

Do not commit unless the user asks.
