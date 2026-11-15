# Swift style

These follow the rules of the owner's iOS app.

- No comments that repeat the code. A comment is allowed only for a fact the code cannot show: an ordering dependency, a workaround, a value that looks arbitrary. One line.
- `guard` for early exit. `== false` instead of `!`.
- Member order: nested types, properties, static properties, `init`, lifecycle, public methods, private methods. Private helpers go in a `private extension`. Each protocol conformance in its own extension with `// MARK: - Name`.
- `init` only assigns properties. Start work in `start()`.
- In a `[weak self]` closure the first line is `guard let self else { return }`. After that, no `self.`.
- Omit `self.` unless Swift requires it or a name is shadowed.
- No default parameter values, except dependency injection in `init`.
- Block indentation for calls that do not fit on one line: first argument on a new line, every argument indented one level, `)` on its own line.
- `public private(set)` when outside code reads a property but must not write it.
- Swift 6 language mode in both packages. Every type that crosses a task boundary is `Sendable`. `@MainActor` is explicit on observable classes.

## Concurrency

- Parsing, filtering and scanning run in `Task.detached` with a value snapshot (`LogContent` is a struct). Check `Task.isCancelled` after every await.
- A long loop calls `Task.checkCancellation()` every few thousand items.
- Never block the main actor on file IO.

## Performance

- Never load a whole file into a `String`. Work on bytes.
- Never call `reloadData()` for appended rows. Use `insertRows`.
- Measure with `PerformanceTests` after a change in `Parsing` or `Filtering`. Targets are in `docs/architecture.md`.
