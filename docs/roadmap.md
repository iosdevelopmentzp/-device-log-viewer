# Roadmap

## Next

1. **Choose the profile by hand** for an opened file (File → Parse As…), for a file whose name matches no profile and that is not JSON lines.
2. **Live `os_log` stream** from a simulator as a second source: `xcrun simctl spawn <UDID> log stream --style ndjson --predicate 'subsystem BEGINSWITH "<prefix>"'`. The built-in JSON lines profile already reads the `log show --style ndjson` keys.
3. **Profile editor** in Settings: show the parsed keys of the profile and a preview of one parsed line, so a mistake in `profile.json` is visible without opening a file.
4. **Folders on the Mac** as a discovery source (a profile could name a folder of log files written by a macOS app or a server).

## Done

Physical devices, several windows and tabs, saved filter presets, regex search, time range, export, the JSON tree, "clear the view", log profiles per project.

## Recommendations for a logger that writes files for LogReader

A logger that writes one JSON object per line (`timestamp` in ISO 8601 with `Z`, `level`, `subsystem`, `category`, `message`, `file`, `line`, other keys as fields) needs no profile. For a text format:

1. **Timestamp with a zone**, or a fixed zone named in the profile.
2. **A header line** `{"v":1,"sep":"\u001e"}` and a one-byte separator after every entry, so multi-line entries never split.
3. **File names without `:`** (`log-2026.10.08-00.18.54.txt`). Finder shows `:` as `/`, and zip and other tools have problems with it.
4. **Keep the metadata order fixed** in every build configuration (a token that is sometimes missing is fine; a token that moves is not).
