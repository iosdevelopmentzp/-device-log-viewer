---
name: layer-templates
description: Code templates for every kind of file in the LogReader architecture - port, AppKit adapter, Foundation adapter, test fake, use case, store, view model, UI model, formatter, display extension, SwiftUI view, NSViewRepresentable, test. Use when creating a new file in LogReaderCore, LogReaderKit or the app target, so the file has the right shape, access level, isolation and member order.
---

# Layer templates

Copy the shape, rename, delete what you do not need. Member order: nested types, properties, static properties, `init`, lifecycle, public methods, private methods. One type per file.

## Port (kit, `Application/Ports/Pasteboard.swift`)

```swift
import Foundation

@MainActor
public protocol Pasteboard: AnyObject {
    func write(text: String)
    func write(fileURL: URL)
}
```

`@MainActor` only when the adapter is AppKit. A port for storage or discovery is nonisolated and `Sendable` when a detached task calls it.

## AppKit adapter (app, `Platform/SystemPasteboard.swift`)

```swift
import AppKit
import LogReaderKit

final class SystemPasteboard {
}

// MARK: - Pasteboard

extension SystemPasteboard: Pasteboard {

    func write(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func write(fileURL: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([fileURL as NSURL])
    }
}
```

## Foundation adapter (kit, `Infrastructure/UserDefaultsBookmarkRepository.swift`)

```swift
import Foundation

public final class UserDefaultsBookmarkRepository {

    private let store: any KeyValueStore

    private static let key = "bookmarks.byFilePath"

    public init(store: any KeyValueStore) {
        self.store = store
    }
}

// MARK: - BookmarkRepository

extension UserDefaultsBookmarkRepository: BookmarkRepository {

    public func bookmarks(for url: URL) -> Set<Int> { ... }

    public func save(_ offsets: Set<Int>, for url: URL) { ... }
}
```

## Test fake (kit tests, `Fakes/FakePasteboard.swift`)

```swift
import LogReaderKit

@MainActor
final class FakePasteboard: Pasteboard {

    private(set) var writtenTexts: [String] = []
    private(set) var writtenFileURLs: [URL] = []

    func write(text: String) {
        writtenTexts.append(text)
    }

    func write(fileURL: URL) {
        writtenFileURLs.append(fileURL)
    }
}
```

## Use case (kit, `Application/UseCases/CopyEntries.swift`)

```swift
import Foundation

@MainActor
public struct CopyEntries {

    private let pasteboard: any Pasteboard

    public init(pasteboard: any Pasteboard) {
        self.pasteboard = pasteboard
    }

    public func copy(recordIndices: [Int], from session: LogSession) {
        let text = recordIndices
            .compactMap(session.record(at:))
            .map(session.text(of:))
            .joined(separator: "\n")
        pasteboard.write(text: text)
    }
}
```

## Store or session (kit, `Application/Workspace/SidebarStore.swift`)

```swift
import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SidebarStore {

    public private(set) var devices: [SimulatorDevice] = []
    public var collapsedAppIDs: Set<String> = []

    @ObservationIgnored public weak var observer: (any SidebarStoreObserver)?

    @ObservationIgnored private let discovery: any LogDiscovery
    @ObservationIgnored private let scanInterval: Duration
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    public init(discovery: any LogDiscovery, scanInterval: Duration) {
        self.discovery = discovery
        self.scanInterval = scanInterval
    }

    public func start(bundleIDPrefix: String) { ... }

    public func stop() { ... }
}

// MARK: - Private

private extension SidebarStore {
    ...
}
```

Observer protocol, own file:

```swift
@MainActor
public protocol SidebarStoreObserver: AnyObject {
    func sidebarStoreDevicesDidChange(_ store: SidebarStore)
}
```

## Pure decision (kit or core, `Application/Workspace/NewestFilePolicy.swift`)

```swift
import Foundation
import LogReaderCore

public enum NewestFilePolicy {

    public static func fileToOpen(current: URL, previousLatest: [String: String], devices: [SimulatorDevice]) -> URL? { ... }
}
```

## UI model (kit, `Presentation/Models/SidebarFileItem.swift`)

```swift
import Foundation

public struct SidebarFileItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let title: String
    public let sizeText: String
    public let isNewest: Bool

    public var id: String { url.path }

    public init(url: URL, title: String, sizeText: String, isNewest: Bool) { ... }
}
```

## Formatter (kit, `Presentation/Formatting/TimeTextFormatter.swift`)

```swift
import Foundation

public struct TimeTextFormatter: Sendable {

    private let timeZoneMode: TimeZoneMode

    private static let localTime = makeFormatter("HH:mm:ss.SSS", timeZone: .current)

    public init(timeZoneMode: TimeZoneMode) {
        self.timeZoneMode = timeZoneMode
    }

    public func time(_ timestamp: TimeInterval?) -> String { ... }
}
```

## Display extension (kit, `Presentation/Display/Appearance+Display.swift`)

```swift
public extension Appearance {

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String { ... }
}
```

## View model (kit, `Presentation/ViewModels/FilterMenuViewModel.swift`)

```swift
import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class FilterMenuViewModel {

    private let session: LogSession

    public var levelOptions: [LevelOption] {
        LogLevel.allCases.map { LevelOption(level: $0, title: $0.title, isOn: session.filterState.facets.levels.isSelected($0)) }
    }

    public var bookmarksOnly: Bool {
        get { session.filterState.bookmarksOnly }
        set { session.setBookmarksOnly(newValue) }
    }

    public init(session: LogSession) {
        self.session = session
    }

    public func toggle(_ level: LogLevel) {
        session.toggleFacetValue(level.code, in: .level)
    }
}
```

## SwiftUI view (app, `Features/Toolbar/FilterMenu.swift`)

```swift
import LogReaderKit
import SwiftUI

struct FilterMenu: View {

    @Bindable var model: FilterMenuViewModel

    var body: some View {
        Menu {
            Section("Levels") {
                ForEach(model.levelOptions) { option in
                    Toggle(option.title, isOn: Binding(get: { option.isOn }, set: { _ in model.toggle(option.level) }))
                }
            }
            Toggle("Bookmarks Only", isOn: $model.bookmarksOnly)
        } label: {
            Label("Filters", systemImage: model.symbolName)
        }
    }
}
```

Small subview with values and closures:

```swift
struct StatusBar: View {

    let item: StatusBarItem
    let onJumpToEnd: () -> Void

    var body: some View { ... }
}
```

## NSViewRepresentable (app, `Features/LogTable/LogTableView.swift`)

```swift
struct LogTableView: NSViewRepresentable {

    let presenter: LogTablePresenter
    let fontSize: Double
    let expandsRows: Bool

    func makeCoordinator() -> LogTableCoordinator {
        LogTableCoordinator()
    }

    func makeNSView(context: Context) -> NSScrollView { ... }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.configure(fontSize: fontSize, expandsRows: expandsRows)
        context.coordinator.attach(presenter)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: LogTableCoordinator) {
        coordinator.detach()
    }
}
```

## Test (kit tests, `FilterMenuViewModelTests.swift`)

```swift
import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct FilterMenuViewModelTests {

    @Test func togglingALevelSelectsOnlyThatLevel() throws {
        let session = LogFixtures.session()
        let model = FilterMenuViewModel(session: session)

        model.toggle(.error)

        #expect(model.levelOptions.first { $0.level == .error }?.isOn == true)
        #expect(session.filterState.facets.levels == .only([.error]))
    }
}
```
