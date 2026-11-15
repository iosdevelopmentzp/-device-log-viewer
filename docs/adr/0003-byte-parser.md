# 0003. Byte-based parser without memory mapping

Date: 2026-10-08. Status: accepted.

## Context

The old viewer in the iOS debug menu reads the whole file into a `String` and splits it. This is slow on large files and uses a lot of memory. Memory mapping (`Data(contentsOf:options:.alwaysMapped)`) is fast, but the app truncates the file on "Clear logs" in its debug menu. A read from a mapped page after a truncate crashes the process (`SIGBUS`).

## Decision

- The tailer reads new bytes with `FileHandle` into normal `Data` and never maps the file.
- The parser works on bytes: it finds separators with `memchr` and parses only the header line of each entry, from the end of the line.
- The message summary and the field preview are decoded during indexing. The full text is decoded only on demand.

## Consequences

- A 50 MB file is indexed in about 20 ms in a release build.
- The whole file is kept in memory once (as chunks). This is fine for files up to a few hundred MB.
