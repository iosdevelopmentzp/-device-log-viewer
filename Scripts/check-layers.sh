#!/usr/bin/env bash
# Checks the layer rules that the compiler cannot enforce. See .claude/rules/layers.md.
set -u

cd "$(dirname "$0")/.."

CORE=Packages/LogReaderCore/Sources
KIT=Packages/LogReaderKit/Sources/LogReaderKit
APP=LogReader
ALLOW=Scripts/check-layers-allow.txt
failures=0

report() {
    echo "✗ $1"
    failures=$((failures + 1))
}

forbid() {
    local description=$1 pattern=$2
    shift 2
    local hits
    hits=$(grep -rnE --include='*.swift' "$pattern" "$@" 2>/dev/null || true)
    if [ -n "$hits" ]; then
        report "$description"
        echo "$hits" | sed 's/^/    /'
    fi
}

forbid_except() {
    local description=$1 pattern=$2 exclude=$3
    shift 3
    local hits
    hits=$(grep -rnE --include='*.swift' "$pattern" "$@" 2>/dev/null | grep -vE "$exclude" || true)
    if [ -n "$hits" ]; then
        report "$description"
        echo "$hits" | sed 's/^/    /'
    fi
}

if [ -d "$CORE" ]; then
    forbid "Core imports a UI or Observation framework" '^import (AppKit|SwiftUI|Observation|Cocoa)' "$CORE"
    forbid "Core uses UserDefaults" '\bUserDefaults\b' "$CORE"
fi

if [ -d "$KIT" ]; then
    forbid "Kit imports AppKit or SwiftUI" '^import (AppKit|SwiftUI|Cocoa)' "$KIT"
    forbid "Kit names an AppKit type" '\bNS(Pasteboard|OpenPanel|SavePanel|Alert|Workspace|App|Appearance|Font|Color|View|Menu)\b' "$KIT"
    forbid_except "Kit uses UserDefaults or FileManager outside Infrastructure" '\b(UserDefaults|FileManager)\b' "$KIT/Infrastructure/" "$KIT"
    forbid_except "Kit names an infrastructure adapter outside Infrastructure" '\b(UserDefaultsBookmarkRepository|SimulatorLogDiscovery|FileTailerSourceFactory|FileManagerCopier|FileManagerTrasher|FileManagerSourceFileIndex|ProcessSourceOpener|FileLogProfileLoader|DataFileWriter|DataFileContentSearcher|DevicectlRunner|PhysicalDeviceDiscovery|CompositeLogDiscovery|RoutingLogSourceFactory|DeviceFileMirror|DeviceLogSource|GitAppUpdater)\b' "$KIT/Infrastructure/" "$KIT"
    forbid "Presentation calls the filter engine, the indexer or the tailer" '\b(LogFilterEngine|LogIndexer|LogFileTailer|SimulatorLogScanner|LogRecordBuilder|LogHeaderLineParser)\b' "$KIT/Presentation"
    forbid_except "Application calls the filter engine outside FilterResult" '\bLogFilterEngine\b' 'FilterResult\.swift' "$KIT/Application"
fi

if [ -d "$APP" ]; then
    forbid "App names a core service or storage type" '\b(LogFilterEngine|LogIndexer|LogFileTailer|SimulatorLogScanner|LogRecordBuilder|LogHeaderLineParser|LogContent|LogRecord|LogEntryDetails|TextQuery|LogBatch)\b' "$APP"
    forbid "App uses UserDefaults" '\bUserDefaults\b' "$APP"
    forbid_except "App uses a system service outside Platform" '\bNS(Pasteboard|OpenPanel|SavePanel|Alert|Workspace)\b|\bNSApp\b' "$APP/Platform/" "$APP"
    forbid_except "App names a port adapter outside the composition root" '\b(SystemPasteboard|WorkspaceFileRevealer|AppKitFileDialogs|AppKitAppearanceApplier|AppKitAppAttention|UserDefaultsBookmarkRepository|SimulatorLogDiscovery|FileTailerSourceFactory|FileManagerCopier|FileManagerTrasher|FileManagerSourceFileIndex|ProcessSourceOpener|FileLogProfileLoader|DataFileWriter|DataFileContentSearcher|DevicectlRunner|PhysicalDeviceDiscovery|CompositeLogDiscovery|RoutingLogSourceFactory|DeviceFileMirror|DeviceLogSource|GitAppUpdater|DefaultLogSessionFactory)\b' "$APP/App/AppDependencies\.swift|$APP/Platform/" "$APP"
    forbid_except "App switches over LogLevel outside Theme" 'case \.(debug|info|notice|warning|error|fault):' "$APP/Theme/" "$APP"
fi

# One top-level type per file.
while IFS= read -r file; do
    count=$(grep -cE '^(public |internal |package |fileprivate |private )?(final |nonisolated |@MainActor )*(struct|class|enum|actor|protocol) [A-Za-z_]' "$file" || true)
    if [ "${count:-0}" -gt 1 ]; then
        if [ -f "$ALLOW" ] && grep -qxF "$file" "$ALLOW"; then
            continue
        fi
        report "More than one top-level type in $file ($count). Split it or list it in $ALLOW."
    fi
done < <(find "$CORE" "$KIT" "$APP" -name '*.swift' 2>/dev/null | sort)

if [ "$failures" -eq 0 ]; then
    echo "✓ Layer checks passed."
    exit 0
fi
echo "$failures layer check(s) failed."
exit 1
