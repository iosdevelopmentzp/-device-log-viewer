# 0001. NSTableView for the log table

Date: 2026-10-08. Status: accepted.

## Context

A log file can have 100 000 entries or more, and new entries arrive several times per second. SwiftUI `List` and `Table` become slow with this many rows, and they have no cheap way to append rows without a full update.

## Decision

The log table is an AppKit `NSTableView` in an `NSViewRepresentable` (`LogTableView`). Rows have a fixed height, cells are reused, and new entries are added with `insertRows`. The rest of the UI stays in SwiftUI.

## Consequences

- Scrolling and appends stay fast on large files.
- The table code uses the AppKit delegate and data source pattern, not SwiftUI state.
- In normal mode rows have one height. The full text is in the inspector.
- Expand Rows mode uses `tableView(_:heightOfRow:)`. The expanded message always uses the monospaced font, so every line holds the same number of characters. `LogEntryText.wrappedLineCount` counts the wrapped lines of the message and the fields on the bytes of the entry, without building strings or laying out text. The cell (`ExpandedTextView`) wraps the same text at the same column with `LogTextMetrics.wrappedLineRanges` and draws only the lines inside the dirty rectangle, so the height and the drawn text always match and a long entry costs little to scroll. A row shows at most 1000 lines and then a note that the inspector has the rest. Heights are cached per record together with the column count, which depends on the Message column width and the group badge or indent.
