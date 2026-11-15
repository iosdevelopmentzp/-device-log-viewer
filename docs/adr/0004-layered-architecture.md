# 0004. Three layers in three modules

Date: 2026-10-10. Status: accepted.

## Context

The MVP grew to about 4 700 lines. The app target mixed four kinds of code in one place:

- `LogDocument` (538 lines) owned the file tail, the content, the filter state, the search, the bookmarks, the selection, the follow mode, the clipboard and the table events.
- `Workspace`, `LogDocument` and `AppSettings` imported AppKit for `NSOpenPanel`, `NSPasteboard` and `NSAppearance`.
- Every view took a whole `LogDocument` or `Workspace` and called many of its methods. A view could not be built or tested without the real store.
- Display strings and colors lived in model enums (`AppSettings.Appearance.title`), in formatters and in views.
- Most files held several types (`MainView.swift` had four views, `LogTableComponents.swift` had three AppKit classes).

Nothing stopped a view from calling the parser, or a store from opening a panel. Only the core package had tests.

## Decision

The app has three layers. Each layer is a separate module, so the compiler enforces the direction of the dependencies.

| Layer | Module | Contains | May import |
|---|---|---|---|
| Domain | `Packages/LogReaderCore` | Log format, parser, storage, filter engine, tailer, discovery. Pure Swift. | Foundation |
| Application + Presentation | `Packages/LogReaderKit` | Ports (protocols for system services), stores and sessions, use cases, view models, UI models, formatters. `@Observable`, `@MainActor`. No AppKit, no SwiftUI. | Foundation, Observation, LogReaderCore |
| UI | `LogReader` app target | SwiftUI views, AppKit table and text view, adapters that implement the ports with AppKit, the composition root. | SwiftUI, AppKit, LogReaderKit, LogReaderCore (value types only) |

Direction: `LogReader` → `LogReaderKit` → `LogReaderCore`. Never backwards.

Inside `LogReaderKit`:

- `Application/Ports`: protocols for everything outside the process: pasteboard, file dialogs, Finder, appearance, key-value storage, bookmark storage, log discovery, log sources.
- `Application/...`: `AppSettings`, `Workspace`, `SidebarStore`, `LogSession`, use cases. They depend on ports and on `LogReaderCore` only.
- `Infrastructure`: adapters that need only Foundation or `LogReaderCore` (`UserDefaults`, the file tailer, the simulator scanner).
- `Presentation`: view models, UI models, formatters, display names. They depend on `Application` and never on `Infrastructure`.

The UI target has:

- `Features/*`: views. A view talks to one view model, or receives UI model values and closures.
- `Platform`: adapters that need AppKit (`NSPasteboard`, `NSOpenPanel`, `NSWorkspace`, `NSApp.appearance`).
- `Theme`: colors, fonts and the mapping from `TextStyle` tokens to `NSAttributedString` attributes.
- `App`: entry point, menu commands and the composition root that builds the object graph.

`Scripts/check-layers.sh` checks the rules that the compiler cannot. It fails when a view names a core service type, when the kit imports AppKit, or when a file holds more than one top-level type without being listed as an exception.

## Consequences

- Everything in `LogReaderKit` is tested with `swift test` and fakes for the ports. No Xcode test target is needed.
- A new system service is a port in the kit plus an adapter in `Platform` or `Infrastructure`.
- Public API in the kit needs `public`. This is the price of a module boundary.
- The AppKit table still needs synchronous row updates. `LogSession` tells a weak `LogRowsObserver` about row changes, and `LogTablePresenter` forwards them to the `NSTableView` coordinator. This is the one place where the kit calls back into the UI, and it is a protocol, not a closure.
- The three modules replace the earlier two-layer split (`Store` and `Features`) described in the first version of `docs/architecture.md`.
