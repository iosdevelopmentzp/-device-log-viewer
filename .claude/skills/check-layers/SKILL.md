---
name: check-layers
description: Run the LogReader layer checks and review a diff against the architecture rules (layers, presentation, one type per file, DI). Use before finishing a change, when the user asks to check the architecture, review layering, or verify that a change respects the rules.
---

# Check layers

## 1. Run the script

```bash
Scripts/check-layers.sh
```

Every `✗` line names a rule from `.claude/rules/layers.md` or `.claude/rules/files.md` and the files that break it. Fix the files, do not add exceptions to `Scripts/check-layers-allow.txt` unless the case is listed in `files.md` under "Allowed exceptions".

## 2. Read the diff against the rules

For each changed Swift file, answer:

| Check | Rule |
|---|---|
| Is the file in the folder of its layer? | `layers.md` table |
| Does a view call a session, a store, a port or a formatter? | `presentation.md`: only the view model does |
| Does a view build a string, pick a color or switch on a domain value? | `presentation.md`: UI model and theme do |
| Does a view model hold an AppKit or SwiftUI type? | `presentation.md` |
| Does a store or view model create its own collaborator (`UserDefaults.standard`, `LogFileTailer(...)`, `SimulatorLogScanner(...)`)? | ADR 0005: injected in `init` |
| Does `init` do work? | `swift-style.md`: `start()` |
| Is there a stored `onSomething` closure in a store or view model? | `layers.md`: observer protocol |
| Is a new port paired with an adapter, a fake and a line in `AppDependencies`? | ADR 0005 |
| Is there a new public kit API without a test? | `testing.md` |
| Does a comment repeat the code? | `swift-style.md` |
| Are there two top-level types in a file? | `files.md` |

## 3. Build and test

```bash
cd Packages/LogReaderCore && swift test
cd Packages/LogReaderKit && swift test
xcodebuild -project LogReader.xcodeproj -scheme LogReader -destination 'platform=macOS' build
```

## 4. Report

List each finding as `path:line: rule → fix`. No praise, no summary of what is fine. If nothing is wrong, say that the checks passed and name the commands you ran.
