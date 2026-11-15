# LogReader

A macOS app for reading the log files that an iOS app writes.

The Xcode console cuts long log messages. An app writes full logs to files, and LogReader shows these files. The format of the files is not fixed: each project describes its logs in a small profile file (`.logreader/profile.json`, see `docs/log-format.md`), and a project that writes JSON lines needs no profile at all. LogReader:

- finds the log files of your apps in every iOS simulator by itself;
- reads the log files of an iPhone connected by USB or Wi-Fi (development builds only);
- shows new entries live while the app runs;
- fast search and filters on files of 50 MB and more;
- full entry text with formatted JSON;
- bookmarks, copy, keyboard navigation.

## Build and run

1. Open `LogReader.xcodeproj` in Xcode 26.6 or newer.
2. Run the `LogReader` scheme.
3. Open Settings → Projects and add the folder of your iOS project. The folder holds `.logreader/profile.json`; press "Create Example Profile" to get a starting point, or copy one of `docs/profiles/`.
4. Run the app in a simulator. The simulator and its log files appear in the sidebar.

Without a profile, a file is read as JSON lines (one JSON object per line with `timestamp`, `level`, `message`, `subsystem`, `category`, `file`, `line`; see `docs/log-format.md`). To read any file, open it with ⌘O or drop it on the window.

## Install in /Applications

Install once by hand:

1. Run `Scripts/install.sh` in this working copy. It builds Release, signs the app, quits the running copy, replaces `/Applications/LogReader.app` and opens it.
2. The first run also makes a build clone of the `main` branch of this working copy in `~/Library/Application Support/LogReader/source`. The updater uses only this clone. Local edits, other branches and a running Xcode build in the working copy do not get in its way. A later run from another working copy points the clone at that copy.
3. Signing: put the SHA-1 hash of an Apple Development certificate in `~/.config/logreader/sign-identity` (`security find-identity -v -p codesigning`), or pass `LOGREADER_SIGN_IDENTITY`. Without a certificate the app is signed ad hoc.
4. The install also quits a copy that Xcode runs, because it has the same process name.

### How updates work

1. The installed app checks at launch, then every 5 minutes, and when you choose LogReader → Check for Updates…. It runs `git fetch` in the build clone. The source of the fetch is `main` in the working copy, so a commit in `main` is enough; there is no remote.
2. When `main` has commits that the installed build does not have, a button at the bottom of the sidebar shows "Update available · N". A click lists the commits (short hash and subject) and has "Update Now". A manual check with nothing new shows "Up to date" for 5 seconds.
3. "Update Now" starts `Scripts/update.sh` from the build clone. It runs on its own, so it keeps running when the app quits. It gets the changes, builds, and installs with `Scripts/install.sh`. The button shows the step and the time: "Getting changes · 0:03", "Building · 1:20", "Installing · 2:05".
4. The app closes only for the few seconds when the new bundle replaces the old one. Then it opens again and shows "Updated to <short hash>" until you close the message.
5. When a step fails, the old app keeps running and the button shows "Update failed". A click shows the end of the log and "Try Again".
6. A build that you run from Xcode never checks, because it does not run from `/Applications/LogReader.app`.
7. When the installed commit is not in `main` (for example, you installed from another branch), the app shows no update until you install from `main` again.

Files in `~/Library/Application Support/LogReader/`:

| Path | What it is |
|---|---|
| `source/` | The build clone. Its `origin` is the working copy. Its `DerivedData/` keeps the builds incremental. |
| `update/installed.json` | The installed commit, the branch, the clone path and the install time. `install.sh` writes it. |
| `update/status.json` | The step of a running or finished update. The scripts write it, the app reads it. |
| `update/update.log` | The full output of the last update. |
| `update/update.lock` | The process ID of the running `update.sh`. |

To start again from zero, delete `~/Library/Application Support/LogReader/` and run `Scripts/install.sh` again.

The app icon is drawn by `Scripts/make-icon.swift`. To change it, run `swift Scripts/make-icon.swift /tmp/icon.png` and cut the sizes into `LogReader/Assets.xcassets/AppIcon.appiconset` with `sips`.

## Window

- **Sidebar**: connected iPhones first, then simulators (booted first) → apps → log files (newest first). "Opened Files" shows files you opened by hand. The field above the list filters by file name, bundle ID or simulator name (Escape clears it). The power button shows only running simulators. The "Search inside files" button (magnifying glass on a page) changes the field: the text is then searched inside every shown log file. Only files that contain the text stay in the list, each with the number of matches. Files over 200 MB show "skipped". A click on a result opens the file with the text in the main search, in Find mode.
- **Connected iPhones**: an iPhone connected by USB or Wi-Fi shows its name, iOS version and connection ("iOS 27.0.1 · Wi-Fi" or "USB"). Under it are the apps that match the bundle ID prefix, with their log files. Only development builds (installed from Xcode) are listed, because only they let a Mac read their files. A phone that is paired but not reachable is not shown. A click on a file copies it from the phone with `xcrun devicectl` into `~/Library/Caches/LogReader/Devices/<device>/<bundle ID>/`. The first copy of a 0.5 MB file takes under 1 second over Wi-Fi. After that, LogReader checks the file every 1.5 seconds and copies the new part, so new entries appear after 1 to 3 seconds. LogReader never changes or deletes files on the phone. "Search inside files" skips a phone file that has not been copied yet.
- **Right click on a row**: copy the entry, the message or the entry as JSON, bookmark it, show only or hide its level or any attribute value, search for its message, "Open in Xcode" (or the editor of the profile) to open the source line of the entry, "Show in Full Log" to clear filters and see the entry with its neighbors, or clear the entries before or after it, or the selected entries.
- **Right click in the sidebar**: on a file — Open in New Window, Show in Finder, Copy Path, Copy File (to paste into Slack or Finder), Save a Copy…, Share…, Move to Trash; on an app — Logs folder, Bundle ID, Copy Latest File, Delete Older Files…, Delete All Logs…; on a simulator — UDID, its folder, Delete All Logs of This Simulator…; on an iPhone — its identifier, its name, its cache folder. Files, apps and phones of a connected iPhone have no delete actions.
- **Table**: one row per log entry. Columns: `#`, Time, Δ (time from the previous entry), Level, one column per attribute of the profile (for example Tags, Category, Source), Message. Rows of a level with `highlightsRow` (for example errors) are tinted with the level color. Bookmarked rows have a blue mark on the left.
- **Expand Rows** (⌘E): every row shows the full text of its entry, not only the first line.
- **Columns, row density and font** (View menu): View → Columns shows or hides each column except Message. View → Row Density switches between Compact and Comfortable rows. View → Font switches the table and the inspector between a monospaced and the system font. The choices are saved.
- **Collapse Repeated Entries** (⇧⌘R, View menu or toolbar button): consecutive entries with the same message and the same level are shown as one row with a count, for example "×12". Click the triangle next to the count, or press → on the selected row, to show every entry of the group. Press ← to hide them again. Find, bookmarks and Go to Entry open the group when they move to an entry inside it.
- **Inspector** (right): the full text of the selected entry. JSON fields are formatted. Search matches are highlighted. The copy menu has Copy Entry, Copy Message, Copy as JSON and one item per field. Click the Source value to open the source line in Xcode. Links (`http`, `https`, `file`) in the entry text are blue and open in the browser on click. Double click a word to highlight all its occurrences with the inspector search. Select text and right click for **Search for “…” in Log**: the list search switches to Find mode with that text.
- **JSON tree** (inspector): when a field of the entry holds a JSON object or array, a JSON section appears below the entry text. Switch it between Text and Tree. Tree shows each JSON field as a tree with sorted keys: click a row or its arrow to open or close an object or array. The root and its first level are open when you select an entry. Right click a row for Copy Value, Copy Key Path (for example `$.items[2].name`) and Copy JSON. The section is hidden while the inspector search has text, so the matches stay in view. A JSON value with more than 5 000 nodes has no tree. The Text / Tree choice is saved between launches.
- **Log → Clear All Bookmarks**: removes every bookmark of the open file. No shortcut.
- **File → Export Visible Entries as Log… / as JSON…**: saves the entries that the current filters show to a new file and shows it in Finder. The log export keeps the framing of the profile, so LogReader can open it again. The JSON export is an array with one object per entry, the same object as "Copy as JSON". The suggested name is the file name with `-filtered`. No shortcut.
- **Several windows** (File → New Window, ⌘N): every window has its own sidebar, open file, filters, search and inspector. Each window reads its file live. Closing one window does not change the others. Right click a file in the sidebar and choose **Open in New Window** to show it next to the current file.
- **Tabs**: LogReader uses the native macOS window tabs. Choose Window → Merge All Windows to put the open windows into one window with tabs. To open every new window as a tab, set System Settings → Desktop & Dock → "Prefer tabs when opening documents" to Always.
- **Status bar**: Live / File removed, entry count, file size, "Exporting…" while an export runs, Following or the "N new" button.

## Search

- **Search in** (the magnifying glass in the search field): choose the columns for the search. Default: Message and fields. You can add every searchable attribute of the profile and Level.
- **Recent searches** (the clock in the search field): the last 30 searches with their mode and scope. A search is saved when you press Return or leave the field. Type to filter the list. Click or press Return to use a search again. Pin a search to keep it at the top. Clear History removes all searches that are not pinned.
- **Regular expression** (the `.*` button in the search field): treat the search text as a regular expression, for example `user/\d+/event` or `fail(ed|ure)`. The search is not case-sensitive. When the expression is not valid, the field border turns orange, the tooltip of the field shows the error, and the text part of the filter is ignored until you fix it. The choice is saved between launches. Recent searches and presets keep it.
- **Filter** mode shows only the entries that contain the text.
- **Find** mode shows every entry, highlights matches, and moves between them with Return, ⌘G / ⇧⌘G.
- **Extra conditions** (the `+` in the search field): add up to three more conditions without any special syntax. Each condition is a row under the toolbar: choose "Also contains" or "Does not contain", type the text, and press × to remove the row. An entry must match every condition and the main search text. The conditions use the same scope and the same regular expression switch as the main field. They work in Filter mode and in Find mode. Text from "Also contains" is highlighted like the main search; text from "Does not contain" is not. An empty condition is ignored. Presets keep the conditions, and Clear Filters removes them.
- **Column filters**: click the Level header or the header of an attribute column. Nothing is checked by default, so every entry is shown. Check values to show only them; uncheck all (or press Clear) to show everything again. Hover a value and press "Only" to keep just that value. Source uses the file name without the line number. "◉" in a header means the filter of this column is on. Switch the popover to "Hide checked" to hide the checked values instead; then the hover button reads "Hide", and the header shows "⊘".
- The Filters menu in the toolbar has Recent Filters (the last 10 filter sets, saved 3 seconds after the last change), level presets, Bookmarks Only and Clear Filters (⌘K).
- **Presets**: save a set of filters under a name and use it again later. A preset keeps the search text, the extra conditions, Filter or Find mode, the search scope, the level and column filters, and Bookmarks Only. Set the filters, open the Filters menu and choose Save Current Filters as Preset…. The name field shows a short summary of the filters; change it or keep it. A name that already exists replaces that preset. Choose a preset at the top of the Filters menu, or in Log → Presets, to apply it. The first nine presets have the shortcuts ⌃⌘1 … ⌃⌘9. Manage Presets… lets you rename, delete and reorder presets by dragging. Presets are saved between launches.
- **Time range**: show only the entries between two times. Open Filters → Time Range… (⌥⌘T). The fields are filled from the current range, the selected entries, or the first and last visible entry. Type `2026-10-07 22:18:54.787`, `22:18:54.787`, `22:18:54` or `22:18`. A time without a date uses the day of the first visible entry. Times use the time zone from Settings. Leave End empty to show everything after Start. Entries without a time are hidden while the range is on. In the row context menu, Show Only From This Entry and Show Only Between Selected Entries set the range from the entries.
- **Clear the view**: hide entries from the table. The file does not change. **Clear All Entries** (⌘⇧M) hides every entry that is already in the file; new entries still appear. Use it before you repeat a step in the iOS app. In the row context menu, **Clear Entries Before This** and **Clear Entries After This** hide the entries before or after the clicked entry (the clicked entry stays), and **Clear Selected Entries** hides the selected rows. "Clear Entries After This" hides only the entries that are already in the file. New entries still appear. The Log menu and the Filters menu have the same items for the selected entry. While something is cleared, an orange banner above the table shows "Showing N of M entries" and one part for each kind of cleared entries. Press × on a part to bring those entries back, or **Restore All** (⌘⇧⌫). Clear Filters and Show in Full Log also restore every entry. Applying a preset keeps the cleared entries and removes the time range.
- **Filter chips**: when a filter is on, a bar above the table shows one chip for each part: search, levels, each column filter, Bookmarks Only, time range. A chip for hidden values starts with "Not" and is orange. Press × on a chip to remove that part, or Clear All to remove every filter.
- **Search in the entry** (⌥⌘F): a second search field in the inspector, only for the selected entry. Return or ↑↓ move between matches.
- Colors: matches of the list search are yellow (in the list and in the inspector). Matches of the inspector search are orange.

## Keyboard shortcuts

| Keys | Action |
|---|---|
| ⌘N | New window |
| ⌘O | Open a log file |
| ⌘F | Search |
| ⌘G / ⇧⌘G | Next / previous match (Find mode) |
| ⌥⌘F | Search in the selected entry (inspector) |
| ⌘L | Jump to the end and follow new entries |
| ⌘J | Go to entry number |
| ⌘B | Bookmark the selected entries |
| ⌘] / ⌘[ | Next / previous bookmark |
| ⌥⌘B | Show bookmarks only |
| ⌘K | Clear filters |
| ⌘⇧M | Clear all entries: show only entries that arrive after this moment |
| ⌘⇧⌫ | Restore all cleared entries |
| ⌥⌘T | Time range |
| ⌃⌘1 … ⌃⌘9 | Apply filter preset 1 to 9 |
| ⌘C | Copy the selected entries |
| ⇧⌘C | Copy all visible entries |
| Space | Show or hide the inspector |
| ⌥⌘I | Show or hide the inspector |
| ⇧⌘O | Open the source line of the selected entry in Xcode |
| ⌘E | Expand or collapse rows (full entry text in the table) |
| ⇧⌘R | Collapse or expand repeated entries |
| → / ← | Show or hide the entries of the selected repeated group |
| ⇧⌘T | Next theme (System → Light → Dark) |
| ⌘+ / ⌘− / ⌘0 | Font size |

## Settings (⌘,)

**General → Show connected devices** (on by default): lists connected iPhones in the sidebar. When it is off, LogReader never runs `xcrun devicectl`.

**Projects**: the folders of the projects whose logs you read. Each folder holds `.logreader/profile.json`. The list shows the profile name, the path and the state (loaded, no profile, or the error in the file). "Add Folder…" adds a project, "Reload" reads every profile again (they are also read again by themselves when the file changes), "Create Example Profile" writes an example `profile.json` into a folder that has none. The bundle ID prefix, the logs folder and the file name pattern of each app come from its profile. Open in Xcode looks for the source file of an entry under the project folder of the profile and opens it with the editor command of the profile (`xed` by default).

Theme (System / Light / Dark), font size, time zone (Local / UTC), row density (Compact / Comfortable), font (Monospaced / System), the visible columns, and "open the newest log file automatically".

**Alerts**: when an entry with an alert level of the profile (for example error or fault) arrives and LogReader is in the background, the Dock icon bounces once and shows the number of new errors. The badge goes away when you switch back to LogReader. The setting is on by default.

## Documentation

- `CLAUDE.md`: build commands, structure and code rules.
- `CHANGELOG.md`: changes per version.
- `docs/log-format.md`: the log profile schema and the built-in JSON lines format.
- `docs/profiles/`: example profiles.
- `docs/architecture.md`: layers and data flow.
- `docs/adr/`: decisions.
- `docs/roadmap.md`: planned work.
- `docs/refactoring-plan.md`: the layering refactoring, its specification and its differences from the code.
