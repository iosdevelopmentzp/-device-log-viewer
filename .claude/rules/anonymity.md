# Anonymity rules

The repository must not name the owner's projects, company, hosts or people. `Scripts/check-anonymous.sh` checks every file and the last commit message; `Scripts/build.sh` runs it first.

## What the check reads

- `~/.config/logreader/anonymity-denylist.txt` (or the file named by `LOGREADER_DENYLIST`), outside the repository: one word per line, case-insensitive. A line that starts with `re:` is an extended regular expression. A line that starts with `#` is a comment. The file never moves into the repository, and its words never appear in a commit, a doc, a profile or a test.
- Built-in patterns, always on:
  - a `com.` bundle ID that is not `com.apple.`, `com.example.` or the app's own `com.dev.com.LogReader`;
  - an `http://` or `https://` host that is not `github.com` (and its subdomains), `gitlab.com`, `api.anthropic.com`, `claude.ai`, `example.com`, `example.org` (and their subdomains), a `.invalid` host, `localhost`, `127.0.0.1`, `keepachangelog.com`, `semver.org`, `www.apple.com` or `developer.apple.com`.

## Sample vocabulary

Code, tests, example profiles and docs use one set of sample values:

| Thing | Value |
|---|---|
| project | `Example App` (profile `docs/profiles/text-trailing.json`) |
| bundle ID | `com.example.app`, `com.example.chat`, `com.example.a` |
| log folder | `Library/Application Support/Logs` |
| source file | `ApiService.swift:229` |
| API host | `api.example.com` |
| people | `alex`, `sam`, and other plain first names when a test needs more |

## Rules

- A profile that describes the owner's real app lives only in that app's working copy (`.logreader/profile.json`, excluded from git there). The copy in `docs/profiles/` uses the sample vocabulary.
- When the check fails, rename the value to the sample vocabulary. Never add the real word to an allow list.
- A doc or an ADR that must point at the owner's app says "the owner's iOS app" or "the app", not its name.
