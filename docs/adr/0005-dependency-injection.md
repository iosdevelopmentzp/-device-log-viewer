# 0005. Constructor injection with one composition root

Date: 2026-10-10. Status: accepted.

## Context

The MVP created its collaborators inline: `Workspace` built `BookmarkStore(defaults: .standard)` and `LogDocument`, `SidebarModel` built `SimulatorLogScanner`, `AppSettings` used `UserDefaults.standard`. Settings reached `Workspace` through an optional property set in `start()`, and `LogDocument` reported the search scope back through a closure. Nothing could be replaced in a test.

The owner's iOS app uses the Factory library with keypath injection. LogReader is a small app with one window type and about ten services.

## Decision

- Every store, session, use case and view model receives its collaborators in `init`. `init` only assigns them.
- Collaborators that touch the system are typed as ports (protocols in `LogReaderKit/Application/Ports`). Pure core types (`LogContent`, `LogFilter`) are passed as values.
- One composition root, `AppDependencies` in the app target, builds the adapters and the factories. It is the only place that names an adapter type together with a port.
- Views receive a view model through `init`. `SettingsViewModel` is shared through the SwiftUI environment because many views and the menu commands need it.
- Objects that live for one session (`LogSession` and its view models) are built by a factory (`LogSessionFactory`, `SessionViewModels`) that the root creates once.
- Default parameter values are allowed in `init` only for a dependency, and only in the kit's own factories, never in a view model.
- Tests use fakes for ports: `FakePasteboard`, `FakeBookmarkRepository`, `InMemoryKeyValueStore`, `FakeLogSource`, `FakeLogDiscovery`.

No DI library. If the graph grows past what one file can hold, revisit this decision and consider Factory, which the team already knows.

## Consequences

- Every dependency is visible in a signature. A type that needs eight collaborators is a sign that it does too much.
- Adding a service means: a port in the kit, an adapter in `Platform` or `Infrastructure`, one line in `AppDependencies`, one fake in the tests.
- Cross-store notifications use a weak observer protocol (`WorkspaceObserver`, `SidebarStoreObserver`, `LogRowsObserver`), not stored closures.
