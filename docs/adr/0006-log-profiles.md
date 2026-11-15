# 0006. Log profiles: the log format lives in the project, not in the app

Date: 2026-11-15. Status: accepted.

## Context

LogReader was written for the log files of one app. The parser knew the header line of that app, the six level codes, the `#tags`, the `[category]`, the `[File:line]`, the UTC timestamp and the two-space field lines. The discovery knew the bundle ID prefix of that app, the folder `Library/Application Support/Logs`, the file name `log-*.txt`. The theme knew that `ERR` is red and `FLT` is purple. About forty places in three modules carried a piece of that knowledge.

The app should read the logs of any project. Each project knows its own format; the app does not.

## Decision

- A **log profile** describes the logs of one project: where the files are, how the entries are framed, how the header line is parsed, the levels, the attributes and the field lines. The profile is a JSON file at `<project folder>/.logreader/profile.json`, so it lives with the code that writes the logs. The schema is in `docs/log-format.md`.
- The app holds a **list of project folders** (Settings → Projects). It loads every profile at launch and loads it again when the file changes. A profile with an error is shown in Settings with the error; its project is skipped.
- The **profile of a file** is chosen without a question:
  - a file in a simulator or iPhone container: the bundle ID of the app → the first profile whose `discovery.bundleIDPrefix` matches;
  - a file opened by hand: the first profile whose `discovery.fileNamePrefix` and `fileExtension` match the name, else the built-in profile.
- The **built-in profile** is JSON lines: one JSON object per line with the keys that `os.Logger` entries usually have (`timestamp`, `level`, `subsystem`, `category`, `message`, `process`, `thread`, `file`, `line`). A project that writes this format needs no profile. No other format is built in; the format of that app is the example profile `docs/profiles/text-trailing.json` and a profile file in its working copy.
- The **core compiles a profile once** into a `LogEntryGrammar` that works on bytes, like the old parser. A `LogLevel` is an index into the profile's level list; an attribute value is stored in `LogRecord.attributes` at the attribute's position. Facets, search scopes, columns and presets name levels and attributes by their string `id`.
- The **profile is passed per session**: `LogIndexer`, `LogFileTailer`, `LogEntryDetails`, `FacetCounts` and the presenters take it in `init` or as an argument. There is no global profile.
- The **theme maps tokens**, not levels: a level has a `style` from a fixed palette (`secondary`, `blue`, `teal`, `green`, `yellow`, `orange`, `red`, `purple`), and flags `alerts`, `highlightsRow`, `colorsMessage`. The app never names a level.

## Consequences

- Features that were fixed are now derived: the level menu, the facet popovers, the table columns, the search scopes, the context menu entries, the JSON export keys, the error alert, the "Open in Xcode" action (attribute with `role: source`).
- Old saved values keep working: `source.projectRoot` becomes the first project folder; `table.hiddenColumns` and `settings.searchScope` map to the new ids; presets with the old level numbers map to the ids `debug`, `info`, `notice`, `warning`, `error`, `fault`.
- A profile change is a project change, not an app release.
- Cost: one more indirection in the parser (a compiled token list instead of fixed code). The performance targets in `docs/architecture.md` stay and are measured for every grammar kind.
- Known limits are listed in `docs/log-format.md`.
