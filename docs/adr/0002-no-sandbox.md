# 0002. App Sandbox is off

Date: 2026-10-08. Status: accepted.

## Context

The app must read `~/Library/Developer/CoreSimulator/Devices` to find the log files. Later it must run `xcrun devicectl` and `xcrun simctl`. A sandboxed app can read this folder only after the user picks it in an open panel, and it cannot run these tools.

## Decision

`ENABLE_APP_SANDBOX = NO`. LogReader is an internal developer tool and is not published in the App Store.

## Consequences

- The app finds simulators without any setup.
- The app cannot be published in the Mac App Store without a change of this decision.
