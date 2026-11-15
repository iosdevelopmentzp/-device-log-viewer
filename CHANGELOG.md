# Changelog

All notable changes to this project are listed here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `Scripts/check-anonymous.sh`: fails when a file or the last commit message names an owner project, company, host or person (a denylist outside the repository at `~/.config/logreader/anonymity-denylist.txt`, plus built-in patterns for bundle IDs and hosts). `Scripts/build.sh` runs it first. The tests, the docs and the example profile use the sample vocabulary from `.claude/rules/anonymity.md`; the trailing example profile is now `docs/profiles/text-trailing.json` (`Example App`, `com.example`).

### Changed
- `Scripts/install.sh` reads the signing identity only from `~/.config/logreader/sign-identity` or `LOGREADER_SIGN_IDENTITY`.
- Log profiles: the log format is no longer fixed in the app. Each project describes its log files in `<project folder>/.logreader/profile.json` (where the files are, how entries are framed, how the header line is parsed, the levels with their colors, the attributes that become columns and facets, the field lines, the source file extension and the editor command). Settings → Projects holds the project folders; "Create Example Profile" writes a starting point; the profiles are read again when the file changes. A file is read with the profile whose bundle ID prefix matches the app, or whose file name pattern matches, or with the built-in JSON lines profile (one JSON object per line with the keys that `os.Logger` entries have). The old fixed format is now the example profile `docs/profiles/text-trailing.json`; nothing about it stays in the code. Schema: `docs/log-format.md`; decision: `docs/adr/0006-log-profiles.md`.
- Columns, header filters, filter chips, the Filters menu levels, "Search in" scopes, the row context menu, the inspector rows, the JSON export keys and the Dock alert follow the profile. Level colors come from a style token in the profile (`red`, `orange`, …); the Filters menu shows "<alert levels> Only" and "<first highlighted level> and Above" instead of fixed items.
- The entry grammar kinds: `trailing` tokens (the old fixed layout), `leading` tokens (for example `2026-01-05 10:00:00.000 [INFO] [Network] message`), a regular expression with named groups, and JSON lines. Framing kinds: a JSON header line with a separator, a fixed separator, or one line per entry with optional continuation lines.
- Saved presets, recent filters, recent searches, the search scope and the hidden columns keep working: old values map to the new ids (`debug` … `fault`, `tags`, `category`, `source`). The single "Project folder" setting becomes the first entry of Settings → Projects.
- Export as Log keeps the framing of the profile, so an exported file opens with the same profile again.
- Performance: the parser is compiled once per profile and works on bytes as before; the PERF test runs for every grammar kind (see `docs/architecture.md`).

### Removed
- The bundle ID prefix setting (it comes from the profile) and the fixed `log-*.txt` file pattern.

### Fixed
- The zsh scripts in `Scripts/` work when started with `sh` or `bash`: they start again in zsh. Before, `sh Scripts/install.sh` stopped with "unbound variable" or "print: command not found".
- `Scripts/install.sh` points an existing build clone at the working copy it runs from, so updates come from the folder of the last install and not from an older one.

### Added
- Self-update from the local `main` branch: after one run of `Scripts/install.sh`, the installed app checks every 5 minutes (and at launch, and from LogReader → Check for Updates…) whether `main` in the working copy has commits that the installed build does not have. A button at the bottom of the sidebar shows "Update available · N". A click lists the commits and has "Update Now". The update gets the changes into a separate build clone (`~/Library/Application Support/LogReader/source`), builds it there while the app keeps running, and closes the app only for the few seconds when the new bundle replaces the old one. The button shows the step and the time since the start ("Building · 1:20"). After the restart it shows "Updated to <short hash>". When the update fails, the old app keeps running and the button shows "Update failed"; a click shows the end of the log and "Try Again". A build run from Xcode never checks. New script: `Scripts/update.sh`.
- Log files of a connected iPhone: iPhones connected by USB or Wi-Fi appear at the top of the sidebar with the iOS version and the connection ("iOS 27.0.1 · Wi-Fi"). Under each phone are the apps that match the bundle ID prefix and their log files, as for a simulator. Only apps installed from Xcode (development builds) are listed, and phones that are paired but not reachable are hidden. A click opens the file: LogReader copies it from the phone with `xcrun devicectl` into `~/Library/Caches/LogReader/Devices`, then copies the new part every 1.5 seconds, so new entries appear after 1 to 3 seconds. The files on the phone are never changed, so the delete actions are hidden for phones. Settings → General → "Show connected devices" turns it off; then LogReader never runs `devicectl`. Search inside files skips a phone file that has no local copy yet.
- App icon: a log page with level dots and a magnifier, drawn by `Scripts/make-icon.swift`.
- Install script: `Scripts/install.sh` installs a Release build in `/Applications`.
- Column visibility, row density and font: View → Columns shows or hides every column except Message. View → Row Density (Compact / Comfortable) and View → Font (Monospaced / System) change the table rows and text. Settings → Table has the same controls. The choices are saved.
- Extra search conditions: the `+` button in the search field adds a row under the toolbar with "Also contains" or "Does not contain" and a text field. Up to three rows. An entry must match all of them and the main search. They follow the search scope and the regular expression switch, work in Filter and Find mode, are highlighted when positive, and are saved in presets.
- Inspector links and word highlight: `http`, `https` and `file` links in the entry text open on click. A double click on a word highlights it with the inspector search. The text menu has "Search for “…” in Log", which searches the list in Find mode.
- Search inside files from the sidebar: the "Search inside files" button next to the sidebar field searches the text in every shown log file. Only matching files stay, with a match count. A click opens the file with the text in Find mode.
- Several windows: File → New Window (⌘N) and Open in New Window in the sidebar file menu. Each window has its own file, filters and search. Window → Merge All Windows puts them into native tabs.
- JSON tree in the inspector: a JSON section below the entry text shows each JSON field as a tree that you can open and close, with Copy Value, Copy Key Path and Copy JSON in the row menu. A Text / Tree switch turns it off; the choice is saved.
- File → Export Visible Entries as Log… and as JSON…: save the entries that the filters show to a file. A log export opens in LogReader again. The status bar shows "Exporting…" while the file is written.
- Error alerts: when an ERR or FLT entry arrives while LogReader is in the background, the Dock icon bounces once and shows the number of new errors. Switching back to LogReader clears the badge. Settings → Alerts turns it off.
- Collapse Repeated Entries (⇧⌘R, toolbar button): consecutive entries with the same message and level become one row with a "×N" count. The triangle or →/← shows and hides the entries of a group. Find and bookmark navigation open a group when needed.
- Expand Rows mode (⌘E, toolbar button): every row shows the full entry text. Row heights are computed from the bytes of the entry, so large files stay fast.
- Theme menu in the toolbar and "Next Theme" (⇧⌘T) in the View menu.
- Search matches are highlighted in yellow in the Message column, in Filter and in Find mode.
- Column filters: click the Level, Tags, Category or Source header to open a list of values with check boxes, the number of entries per value, a search field, Clear, and "Only" for one value. Nothing is checked by default, so every entry is shown. Checked values are the only ones shown. Source filters by file name without the line number. A header with an active filter shows "◉".
- `FacetFilter` in the core package: "all" or "only these values".
- Inspector search (⌥⌘F): a separate search inside the selected entry. Its matches are orange, the current match is selected and scrolled into view, with a counter and previous / next buttons. The list search stays yellow in the inspector. Where both match, orange wins.
- Search scope menu (the magnifying glass in the search field): choose where the list search looks: Message and fields, Tags, Category, Source, Level. Default is Message and fields. The choice is saved. The icon turns blue when the scope is not the default.
- Context menus in the sidebar (right click):
  - log file: Open, Show in Finder, Open in Default App, Copy Path, Copy File Name, Copy File (paste it into Finder, Slack or Mail), Save a Copy… (the name gets `-` instead of `:`), Share…; Remove from List for opened files;
  - app: Show Logs Folder in Finder, Copy Logs Folder Path, Copy Bundle ID, Copy Latest File;
  - simulator: Copy Simulator UDID, Copy Simulator Name, Show Simulator Folder in Finder.
- Move to Trash in the context menu of a log file. No confirmation, because the Trash can give the file back.
- Delete Older Files… (keeps the newest file) and Delete All Logs… in the context menu of an app. Both ask for confirmation and name the number of files.
- Delete All Logs of This Simulator… in the context menu of a simulator. It asks for confirmation and covers every app of the simulator.
- When the open file goes to the Trash, the newest remaining file of the same app opens. The sidebar shows the change at once, not after the next scan.
- Context menu on table rows (right click): Copy Entry (all selected rows), Copy Message, Copy Source, Add / Remove Bookmark, Show Details, Show in Full Log (clears filters and keeps the entry selected), Show Only Level / Tag / Category / Source of the entry, Search for the message, Clear Filters.
- Clear All Bookmarks in the Log menu, after Show Bookmarks Only. It removes every bookmark of the open file and is disabled when there are none.
- Copy as JSON in the row context menu and in the inspector copy menu, after Copy Message. The JSON has `number`, `level`, `time` (ISO 8601 in UTC), `tags`, `category`, `source`, `message` and `fields`. A field with valid JSON becomes a nested value, every other field is a string. A repeated field name gets a `#2`, `#3` suffix.
- `SearchScope` and `LogRecord.metadataRange` in the core package, so a Message search skips the metadata of the header line.
- Exclude a value: a column filter can hide the checked values instead of showing only them. The popover has a "Show only checked" / "Hide checked" switch. In hide mode the hover button reads "Hide" and the header shows "⊘". The header tooltip names the mode and the number of values.
- "Hide Level / Tag / Category / Source" items in the row context menu, after the "Show Only" items. They add the value to the hidden values of the column, or replace a "show only" filter of that column.
- `FacetFilter.except` and `FacetMode` in the core package. An entry without a value in the column (for example, no category or no tags) stays visible when values are hidden.
- Active filter chips above the table: one chip for each part of the filter (search, levels, each column filter, Bookmarks Only). Hidden values show as "Not …" in orange. The × on a chip removes that part; Clear All removes every filter. The bar shows only when a filter is on.
- Sidebar filter: a field above the sidebar list ("Filter files") shows only the files whose name, app bundle ID or simulator name or runtime contains the text. Case does not matter. Matching apps open automatically. The × button or Escape clears the field. "No Results" shows when nothing matches.
- "Show only running simulators" button (power symbol) next to the sidebar filter. It hides simulators that are not booted. The choice is saved. A line under the field shows "3 of 7 simulators running" when some simulators are off.
- Recent searches: the clock button in the search field opens the last 30 searches (text, Filter or Find, search scope, time). A search is saved when you press Return or leave the field. Type to filter the list, click or press Return to use a search again, pin a search to keep it at the top, remove one, or press Clear History (pinned searches stay). The list is saved between launches.
- Recent Filters in the Filters menu: the last 10 sets of level, column and Bookmarks Only filters, each with a short title such as "ERR, FLT · #network · Bookmarks". A set is saved 3 seconds after the last filter change. Choose one to apply the whole set at once. The list is saved between launches.
- Filter presets: save the current search text, mode, search scope, level and column filters and Bookmarks Only under a name. Save Current Filters as Preset… and Manage Presets… are in the Filters menu and in Log → Presets. The presets are listed at the top of the Filters menu. The first nine have the shortcuts ⌃⌘1 … ⌃⌘9. Manage Presets… renames, deletes and reorders presets. Saving with an existing name replaces that preset. Presets are saved between launches.
- Open the source line in Xcode: Log → Open Source in Xcode (⇧⌘O), "Open in Xcode" in the row context menu, or a click on the Source value in the inspector. The app looks for the file under the project folder from Settings → Source and opens it at the line through `xed`. If several files have this name, a `.swift` file with the shortest path wins.
- Time range filter: Filters → Time Range… (⌥⌘T) shows only the entries between two times. The row context menu has Show Only From This Entry and Show Only Between Selected Entries. A chip shows the range.
- Clear the view: hide entries from the table without changing the file. Clear Entries Before This / After This and Clear Selected Entries in the row context menu, and a Clear section in the Log menu and the Filters menu: Clear All Entries (⇧⌘M), Clear Entries Before / After Selected, Clear Selected Entries, Restore All Entries (⇧⌘⌫). An orange banner above the table shows how many entries are hidden and why, with × on each part and Restore All. "After This" hides only the entries that exist at the moment of the click; new entries still appear. Clear Filters and Show in Full Log restore everything; applying a preset keeps the cleared entries.
- Regular expression search: the `.*` button in the search field treats the search text as a regular expression (not case-sensitive). An invalid expression gives an orange field border and the error in the tooltip, and the search text is ignored until it is fixed. The choice is saved, and Recent searches and presets keep it.

### Changed
- The "Show time from previous entry (Δ)" setting is gone. The Δ column is now one of the toggles in View → Columns and Settings → Columns. A hidden Δ column stays hidden after the update.
- "Mark Now" became "Clear All Entries" (same shortcut ⇧⌘M), and "Clear Mark" became "Restore All Entries". The "After mark" filter chip is gone; the new banner above the table shows the cleared entries instead.
- Tooltips appear after 1.2 seconds instead of the system default.
- The code is split into three modules: `LogReaderCore` (log format, parser, filter engine, tailer, discovery), the new `LogReaderKit` package (ports, settings, `LogSession`, `Workspace`, use cases, view models, UI models, formatters) and the app target (views, AppKit adapters, theme, composition root). Views no longer touch the parser, the filter engine or the clipboard; every system service is a port with one adapter. `Scripts/check-layers.sh` checks the layer rules. One type per file. No user-visible change. See `docs/adr/0004-layered-architecture.md`, `docs/adr/0005-dependency-injection.md` and `docs/refactoring-plan.md`.
- The Filters menu in the toolbar now has only levels, bookmarks and Clear Filters. Tags and categories moved to the column headers.

### Removed
- The git hooks that reinstalled the app after every commit or merge in `main` (`Scripts/install-hooks.sh`, `Scripts/auto-install.sh`). Updates now come from the update button in the app.

### Fixed
- Tooltips on the toolbar buttons (Expand Rows, Follow, Inspector) never appeared: SwiftUI drops `.help` on a toolbar `Button` on macOS 26. The app now sets the tooltip on the `NSToolbarItem` itself. New tooltips on the inspector search buttons, the status bar, the bookmark badge, the copy button and the column filter popover.
- The log table created a new row view for every row it showed and never took one back from the reuse queue of `NSTableView`. Memory grew by about 40 KB for every row that was ever on screen (scrolling, filtering, live tail) and was never given back. Row views are now dequeued with `makeView(withIdentifier:owner:)`, like the cell views.
- The search field is now next to the Filter / Find switch. In Find mode it shows the match position and the previous / next buttons inside the field. Return goes to the next match.
- The row tint for Find matches is lighter, because the matched words now have their own highlight.
- Softer light theme: the table and the inspector use a light warm gray background instead of pure white, and dark gray text instead of black.
- In a selected row, all text is white, so tags and colored text stay readable on the selection color.
- The list search no longer matches the header line metadata (level code, tags, category, source, time) unless these columns are in the search scope.

### Fixed
- Highlighted text was hard to read on the yellow background (for example field names in the inspector). Highlighted text is now black.
- Expand Rows cut the end of long entries. The text wrapped at word boundaries, but the row height was computed for wrapping at any character. The text now wraps at any character too.

## [0.1.0] - 2026-10-08

### Added
- `LogReaderCore` package: byte-based parser of the log format, live file tailer, filter and search engine, simulator discovery. Unit tests and a performance test.
- Sidebar with simulators, apps and log files. It updates every 3 seconds.
- Open a file with ⌘O or drag and drop. Old files without a header are supported.
- Log table on `NSTableView`: columns `#`, Time, Δ, Level, Tags, Category, Source, Message. Row tints for warnings, errors, faults and search matches.
- Live tail: new entries appear while the file grows. A clear or a removal of the file is handled.
- Follow mode and the "N new" button. ⌘L jumps to the end.
- Open the newest log file of an app automatically when a new session starts.
- Search in Filter mode and Find mode. Filters by level, tag, category and bookmarks.
- Inspector with the full entry text, formatted JSON fields, highlighted matches and copy actions.
- Bookmarks per file, saved between launches.
- Copy of selected entries and of all visible entries.
- Settings: theme, font size, time zone, Δ column, bundle ID prefix, follow the newest file.
- Documentation: `CLAUDE.md`, `README.md`, `docs/`.
