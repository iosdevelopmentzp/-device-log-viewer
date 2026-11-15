# Presentation layer

## Shape

```
view (SwiftUI or AppKit, app target)
  └─ view model (@MainActor @Observable, kit)        one per screen, popover or sheet
       └─ session / store / use case (kit)
            └─ ports and core
```

- One view model per screen, popover, sheet or AppKit component: `MainViewModel`, `SidebarViewModel`, `SearchViewModel`, `FilterMenuViewModel`, `FacetFilterViewModel`, `EntryInspectorViewModel`, `LogTablePresenter`, `SettingsViewModel`.
- A small subview (a row, a header, a badge) takes a UI model value and closures. It does not take a view model. Example: `FileRow(item: SidebarFileItem)`, `StatusBar(item: StatusBarItem, onJumpToEnd: () -> Void)`.
- Every string, number, symbol name and style token the view shows comes from the view model or the UI model. A view does not format dates, sizes, counts or titles, and does not build a `String` from model fields.
- A view does not branch on domain state to pick a color or a label. It receives a token (`TextStyle`, `StatusBarItem.Kind`, `LogLevel`) and the theme maps the token.
- A view does not call a port, a use case, a session or a store. Only its view model does.

## UI models

- Plain `struct`s in `Presentation/Models`. `Sendable`, `Equatable`, `Identifiable` when shown in a list. Only values: `String`, `Int`, `Bool`, `URL`, `NSRange`, `LogLevel`, `SearchScope`, `FacetColumn`, other UI models.
- A UI model never holds `LogRecord`, `LogContent`, `LogEntryDetails` or a session.
- Styled text is `StyledText` (string plus spans with `TextStyle` tokens). The app turns it into `NSAttributedString` with `TextStyleSheet`. The kit never names a font or a color.
- Context menus are `[ContextMenuEntry]` built in the kit. The app renders them.

## View models

- `@MainActor @Observable public final class`. `init` assigns dependencies only. Work starts in `start()` or on the first call.
- Expose state as properties and computed properties. Expose actions as methods with verbs: `findNext()`, `toggle(_ level:)`, `saveCopy(of:)`.
- Two-way SwiftUI bindings use a `var` with `get` and `set` on the view model (`var text: String { get { session.filterState.searchText } set { session.setSearchText(newValue) } }`). Views use `@Bindable var model`.
- A view model holds no AppKit or SwiftUI types. `FocusState`, `Binding` and `NSView` stay in the view.
- Display names of enums are extensions in `Presentation/Display`, file `Type+Display.swift`, property `displayName`. The enum itself has no `title`.
- Formatting lives in `Presentation/Formatting`. One formatter per concern. Cache `DateFormatter`s as `static let`.

## AppKit bridging

- `NSViewRepresentable` views are thin: `makeNSView` builds the AppKit view, `updateNSView` forwards values to a coordinator, `dismantleNSView` detaches.
- The coordinator asks the presenter for `rowCount`, `row(at:)`, `lineCount(row:columns:maxLines:)`. It never reads a session.
- Row updates must reach `NSTableView` synchronously, so `LogSession` → `LogRowsObserver` → `LogTablePresenter` → `LogTableUpdateReceiver` → coordinator is a chain of weak protocol references, not closures and not `AsyncStream`.
- Row height has a fixed value in normal mode. Expand Rows uses `LogTextMetrics` through the presenter. No Auto Layout row sizing (ADR 0001).
- Every row view and cell view comes from `makeView(withIdentifier:owner:)` and has its identifier set. A view created per row is never released: AppKit keeps it in the reuse queue and nothing takes it out.

## Settings

- `AppSettings` is application state. Views reach it through `SettingsViewModel` (environment) and never directly.
- Applying the appearance to `NSApp` is an `AppearanceApplier` adapter called from `MainView.onChange`, not a `didSet` in the settings.
