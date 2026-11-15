# Layers

Three modules. The direction is fixed: `LogReader` (app) → `LogReaderKit` → `LogReaderCore`. See `docs/adr/0004-layered-architecture.md`.

| Module | Holds | May import | Must not contain |
|---|---|---|---|
| `Packages/LogReaderCore` | Log format, parser, `LogContent`, filter engine, tailer, discovery, pure helpers | Foundation | `Observation`, AppKit, SwiftUI, `UserDefaults`, anything about windows or views |
| `Packages/LogReaderKit` | Ports, settings, sessions, stores, use cases, view models, UI models, formatters | Foundation, Observation, LogReaderCore | AppKit, SwiftUI, `NSPasteboard`, panels, `NSApp` |
| `LogReader` (app) | Views, AppKit table and text view, port adapters, theme, composition root | SwiftUI, AppKit, LogReaderKit, LogReaderCore | Parser, filter engine, tailer, scanner, `LogContent`, `LogRecord`, `TextQuery`, `UserDefaults` |

## Inside the kit

- `Application/Ports`: one protocol per system service. A port describes what the app needs, not what AppKit offers. `Pasteboard.write(text:)`, not `setString(_:forType:)`.
- `Application/*`: stores and sessions depend on ports and core types only.
- `Infrastructure`: adapters that need only Foundation or the core (`UserDefaults`, `LogFileTailer`, `SimulatorLogScanner`, `FileManager`). Nothing else in the kit names an infrastructure type.
- `Presentation`: view models, UI models, formatters, display names. They read application stores and call their methods. They never call a port directly, except `Pasteboard` through a use case.

## Inside the app

- `Platform`: adapters that need AppKit. One adapter per port. The only files that name `NSPasteboard`, `NSOpenPanel`, `NSSavePanel`, `NSAlert`, `NSWorkspace`, `NSApp`.
- `Theme`: colors, fonts, `TextStyle` → attributes. The only files that switch over `LogLevel` for a color.
- `Features`: views. A view uses a view model or plain UI model values. It never names a core service type and never reads `UserDefaults`.
- `App/AppDependencies.swift`: the only file that pairs a port with an adapter.

## Use case or not

Write a use case (`Application/UseCases`) when an action needs two or more ports or stores, or has a decision worth a unit test. One port, one call: the store or the view model calls the port. Pure decisions (which file to open next, how to name a copy) are static functions on an enum with tests.

## Notifications between objects

Synchronous notifications go through a small protocol with a weak reference: `LogRowsObserver`, `WorkspaceObserver`, `SidebarStoreObserver`, `LogTableUpdateReceiver`. Do not store `onSomething` closures in a store or a view model. Everything else uses `@Observable` tracking.

## Checks

`Scripts/check-layers.sh` enforces the "must not contain" column and the one-type-per-file rule. Run it before you finish a change. A new exception goes into `Scripts/check-layers-allow.txt` with a reason in the commit message.
