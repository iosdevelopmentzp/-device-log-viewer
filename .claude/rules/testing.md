# Testing

Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`). One test file per type: `LogSessionTests.swift` tests `LogSession`.

## What must have tests

| Layer | Test |
|---|---|
| Core: parser, filter engine, tailer, helpers | Every public function. Fixtures as text in the test. |
| Kit: `AppSettings`, `LogFilterState`, `LogSession`, `SidebarStore`, `Workspace`, use cases, `NewestFilePolicy` | Behavior through fakes for the ports. |
| Kit: formatters, builders, view models | Input values → output strings, spans and items. |
| App: views, AppKit, adapters | No unit tests. Verify by running the app. Keep these files thin so there is little to test. |

## Fakes

- One fake per port in `Tests/LogReaderKitTests/Fakes`, named `FakeX` (`FakePasteboard`) or `InMemoryX` (`InMemoryKeyValueStore`).
- A fake records calls in arrays (`writtenTexts`, `revealedURLs`) and returns values set by the test (`fileToChoose`).
- `FakeLogSource` exposes a continuation so a test can push `LogSourceEvent`s and await the session state.
- `LogFixtures` builds a `LogBatch` or a `LogContent` from a text fixture.

## Commands

```bash
cd Packages/LogReaderCore && swift test
cd Packages/LogReaderKit && swift test
cd Packages/LogReaderCore && LOGREADER_PERF=1 swift test -c release --filter PerformanceTests
xcodebuild -project LogReader.xcodeproj -scheme LogReader -destination 'platform=macOS' build
Scripts/check-layers.sh
```

All five pass before a change is done. `Scripts/check-anonymous.sh` must print `anonymous: ok` too (see `.claude/rules/anonymity.md`).
