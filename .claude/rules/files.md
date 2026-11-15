# One type per file

Every top-level `struct`, `class`, `enum`, `actor` and `protocol` lives in its own file named after the type: `LogSession.swift`, `Pasteboard.swift`, `SidebarFileItem.swift`.

## Naming

| File | Holds |
|---|---|
| `Type.swift` | the type and its private extension |
| `Type+Protocol.swift` | a conformance that is long enough to read alone (`LogTableCoordinator+NSTableViewDelegate.swift`) |
| `Type+Display.swift` | display names for an application enum (presentation layer) |
| `Type+Other.swift` | an extension of a type from another module (`UserDefaults+KeyValueStore.swift`, `StyledText+NSAttributedString.swift`) |
| `TypeTests.swift` | the tests of one type |
| `FakeType.swift` | a test fake for a port |

Folders mirror the layer: `Application/Ports`, `Presentation/ViewModels`, `Features/LogTable`, `Platform`, `Theme`. A new folder needs at least two files.

## Allowed exceptions

Keep two types in one file only in these cases. List the file in `Scripts/check-layers-allow.txt`.

1. A protocol and its single implementation, when both fit in about 40 lines together and nothing else will ever conform (`LogSessionFactory` with `DefaultLogSessionFactory`).
2. A view and a private `LabelStyle`, `ButtonStyle` or `ViewModifier` that only this view uses.
3. A SwiftUI `@Entry` extension next to the one type that reads it (`FocusedValues` next to `LogCommands` is not such a case: it gets its own file, because `MainView` writes it too).
4. A `Coordinator` of an `NSViewRepresentable` that is under about 30 lines. A bigger coordinator gets its own file.

Nested types do not count as exceptions. Nest a type when it has no meaning outside its parent: `LogSession.LoadKey`, `StyledText.Span`, `EntryHeaderItem.MetadataRow`. Do not nest a type that another file names in a signature.

## Inside a file

Member order: nested types, properties, static properties, `init`, lifecycle, public methods, private methods. Private helpers in `private extension Type` under `// MARK: - Private`. Each protocol conformance in its own extension under `// MARK: - ProtocolName`.

A file over about 250 lines is a sign that the type does two jobs. Split the type, not the file.
