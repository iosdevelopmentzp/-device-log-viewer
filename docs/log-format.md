# Log profiles and the built-in JSON format

LogReader has no fixed log format. The format of a project's log files is described by a **log profile**: a JSON file at `<project folder>/.logreader/profile.json`. The project folder is added in Settings → Projects. A file that matches no profile is read with the **built-in profile**, JSON lines (see the end of this file).

The core compiles a profile once (`LogEntryGrammar`) and parses the bytes with it. Decision: `docs/adr/0006-log-profiles.md`. Examples: `docs/profiles/text-trailing.json` (a trailing text grammar with a JSON header line), `docs/profiles/text-leading.json` (a leading text grammar, one line per entry with continuation lines), `docs/profiles/regex.json`.

## Which profile reads a file

1. A file found in a simulator or iPhone container: the bundle ID of the app → the first project whose `discovery.bundleIDPrefix` matches. Projects are tried in the order of Settings → Projects.
2. A file opened by hand (⌘O, drop, Opened Files): the first profile whose `discovery.fileNamePrefix` is not empty and whose prefix and `fileExtension` match the file name.
3. Otherwise the built-in profile.

The profiles are read again when `profile.json` changes (checked every 3 seconds). The open file is then parsed again with the new profile.

## Schema

Only `name` and `entry` are required. Every other key has a default.

```json
{
  "name": "My App",
  "discovery": { "bundleIDPrefix": "com.example", "logsPath": "Library/Application Support/Logs", "fileExtension": "txt", "fileNamePrefix": "log-" },
  "framing": { "kind": "header" },
  "entry": { "kind": "trailing", "tokens": [ ... ] },
  "timestamp": { "format": "yyyy-MM-dd HH:mm:ss.SSS", "timeZone": "UTC" },
  "levels": [ { "id": "error", "codes": ["ERR"], "title": "Error", "style": "red", "alerts": true, "highlightsRow": true, "colorsMessage": true } ],
  "attributes": [ { "id": "tags", "title": "Tags", "kind": "list", "prefix": "#" } ],
  "fields": { "indent": 2 },
  "source": { "fileExtension": "swift", "editorCommand": "/usr/bin/xed", "editorArguments": ["--line", "{line}", "{path}"] }
}
```

### `discovery`

Where the files of the app are. Without `discovery`, files of this project open only by hand.

| Key | Default | Meaning |
|---|---|---|
| `bundleIDPrefix` | `""` | Apps whose bundle ID starts with this. Empty matches every app. |
| `logsPath` | `Library/Application Support/Logs` | The logs folder inside the app data container. |
| `fileExtension` | `""` | Only files with this extension. Empty accepts every file. |
| `fileNamePrefix` | `""` | Only files whose name starts with this. The sidebar hides the prefix in the file title. On an iPhone the date in the name after the prefix (`yyyy.MM.dd-HH:mm:ss`) is the creation date. |

### `framing`

How entries are separated in the file.

| `kind` | Meaning |
|---|---|
| `header` | The first line is JSON `{"v":1,"sep":"\u001e"}`; `sep` (one byte) ends every entry. A file without such a line is read as `lines`. |
| `separator` | A fixed one-byte `separator` string ends every entry, no header line. |
| `lines` | One line is one entry. With `"joinsUnrecognizedLines": true`, a line that the entry grammar does not recognize is appended to the previous entry (stack traces, pretty JSON). |

### `entry`

How the header line of an entry is parsed. The header line is the first line of the entry that the grammar recognizes (up to 64 lines are tried, so a message can span lines before its metadata). The rest of the line is the message.

| `kind` | Meaning |
|---|---|
| `trailing` | `tokens` are read from the end of the line backwards. First token in the list = last on the line. |
| `leading` | `tokens` are read from the start of the line. |
| `regex` | `pattern` with named groups: `message` (required), `time`, `level`, and one group per attribute id. |
| `json` | One JSON object per line. Keys: `message` (default `message`, `eventMessage`, `composedMessage`, `msg`, `text`), `time` (`timestamp`, `time`, `date`), `level` (`level`, `messageType`, `type`, `severity`); each may be one string or a list. Attributes read the key named by their `key` (default: the attribute id). Every other top-level key becomes a field in the inspector. |

A token:

| `kind` | Keys | Meaning |
|---|---|---|
| `time` | `open`, `close` (optional) | The timestamp (see `timestamp`). |
| `level` | `open`, `close` (optional) | A word matched against the `codes` of the levels. |
| `delimited` | `attribute`, `open`, `close`, `pattern` | Text between `open` and `close`, for example `[category]`. `"pattern": "file:line"` requires `name:digits` inside. |
| `word` | `attribute` | One word (no spaces). |
| `list` | `attribute`, `prefix` | Repeated words that start with `prefix`, for example `#tag #tag`. |
| `literal` | `text` | Fixed text that must be present. |

Every token has `"required": false` by default (`literal`: true). A line is recognized when every required token matched and a `time` or `level` was found (or, when the grammar has neither, when any token matched). `"requires": "<token name>"` ties a token to another one: the name of a `time` or `level` token is its kind, the name of an attribute token is its attribute id. A token that requires an earlier token is skipped when that token did not match. A token that requires a later token is parsed tentatively and dropped when that token does not match (`text-trailing.json`: `[category]` counts only when a level follows it; without that rule a message like `[REQUEST]` would be a category).

### `timestamp`

| Key | Default | Meaning |
|---|---|---|
| `kind` | `pattern` when `format` is set, else `iso8601` | `pattern`, `iso8601`, `epochSeconds`, `epochMilliseconds`. |
| `format` | — | Fixed-width letters `yyyy` `yy` `MM` `dd` `HH` `mm` `ss` `S…` (fraction digits); every other ASCII character is a literal. |
| `timeZone` | `UTC` | The zone of a `pattern` or of an ISO 8601 value without a zone. |

`iso8601` accepts `2026-10-07T22:18:54.787Z`, a space instead of `T`, `+01:00`, `+0100`, `+01`, and a number (epoch seconds, or milliseconds when above 10^11).

### `levels`

Ordered from lowest to highest. The order is the rank for "X and above".

| Key | Default | Meaning |
|---|---|---|
| `id` | required | Stable id; used in presets and saved filters. |
| `codes` | `[id]` | The exact words that mean this level in the file. The first code is shown in the Level column. |
| `title` | capitalized id | Shown in menus. |
| `style` | `primary` | Color token: `primary`, `secondary`, `blue`, `teal`, `green`, `yellow`, `orange`, `red`, `purple`. |
| `alerts` | `false` | Counts for the Dock alert and for "<alert levels> Only" in the Filters menu. |
| `highlightsRow` | `false` | Tints the row. The lowest such level gives "<level> and Above". |
| `colorsMessage` | `false` | Colors the message text with the style. |

When `levels` is missing, the built-in list is used (`debug`, `info`, `notice`, `warning`, `error`, `fault` with lower-case, capitalized and upper-case codes, plus `trace`, `default`, `warn`, `critical`).

### `attributes`

Extra columns and facets. Order is the column order.

| Key | Default | Meaning |
|---|---|---|
| `id` | required | Stable id; not `level`, `message`, `time`, `number`, `delta`. |
| `title` | capitalized id | Column and menu title. |
| `kind` | `text` | `text` (one value) or `list` (several values). |
| `prefix` | `""` | Shown before every list value (`#`). |
| `facet` | `true` | Header filter, chips, "Show Only" and "Hide" in the row menu. |
| `searchable` | `true` | Offered in "Search in". |
| `role` | — | `source`: the value is `File:line`; the facet uses the file name; the inspector and the row menu get "Open in …". At most one. |
| `key` | id | The JSON key (`json` entries). |
| `lineKey` | — | `json` entries with `role: source`: the key that holds the line number. |
| `columnWidth` | 110 | Points. |
| `hidden` | `false` | Column hidden by default. |

### `fields`

Field lines below the header line: `<indent spaces>key: value`. A value can be many lines long (the next lines have no fixed indentation). A value that is a JSON object or array is pretty-printed in the inspector. Default `indent` is 2.

### `source`

| Key | Default | Meaning |
|---|---|---|
| `fileExtension` | `swift` | Added to a source file name without extension, and preferred when several files share a name. |
| `editorCommand` | `/usr/bin/xed` | Full path of the editor command. |
| `editorArguments` | `["--line", "{line}", "{path}"]` | `{path}` and `{line}` are replaced; `{line}` is dropped when the entry has no line. |

The source file is looked up under the project folder of the profile.

## Built-in profile: JSON lines

A project that writes one JSON object per line needs no profile. Keys (first present wins):

| Part | Keys |
|---|---|
| message | `message`, `eventMessage`, `composedMessage`, `msg`, `text` |
| time | `timestamp`, `time`, `date` — ISO 8601 or epoch |
| level | `level`, `messageType`, `type`, `severity` — `debug`/`trace`, `info`, `notice`/`default`, `warning`/`warn`, `error`, `fault`/`critical` in any letter case |
| attributes | `subsystem`, `category`, `file` + `line` (source), `process` (hidden column), `thread` (hidden, not a facet) |
| fields | every other key; nested values are pretty-printed |

Example:

```
{"timestamp":"2026-10-07T22:18:54.787Z","level":"error","subsystem":"com.example.app","category":"network","message":"Request failed","file":"ApiService.swift","line":229,"payload":{"code":500}}
```

The writer should emit UTF-8 (the default of `JSONEncoder`); `\uXXXX` escapes are decoded in the message, but a search for non-ASCII text does not match an escaped line.

## Known limits

- JSON lines: the search in "Message and fields" scope runs over the whole line, so key names match too.
- `lines` framing with `joinsUnrecognizedLines`: a continuation line that arrives in a later read (after the previous entry was already shown) starts a new, unstructured entry.
- `regex` entries: the metadata is the part of the line before the `message` group (or after it when the message starts the line); text between two groups in the middle of the line is treated as metadata only on one side.
- The `trailing` grammar needs a space before a token (`[cat]` glued to the message is part of the message). A message that ends with a word starting with the list prefix (`#12`) is read as a list value when the level token matched before it.
- Export "as Log" writes the entries in the framing of the profile, so the exported file opens with the same profile again.
