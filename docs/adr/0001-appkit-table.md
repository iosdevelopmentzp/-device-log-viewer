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
- Expand Rows mode uses `tableView(_:heightOfRow:)`. The height comes from `LogTextMetrics.wrappedLineCount`: the font is monospaced, so the number of wrapped lines is computed from the bytes of the entry without text layout. Heights are cached per record and are computed again after a resize of the Message column.
