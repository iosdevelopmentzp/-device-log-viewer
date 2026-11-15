import Foundation
import Observation

@MainActor
@Observable
public final class MainViewModel {

    public let sidebar: SidebarViewModel
    public let presets: FilterPresetsViewModel
    public private(set) var sessionViews: SessionViewModels?
    public var isInspectorPresented = true
    public var isGoToEntryPresented = false
    public var isTimeRangePresented = false
    public private(set) var timeRange: TimeRangeViewModel?
    public private(set) var searchFocusRequest = 0
    public private(set) var inspectorSearchFocusRequest = 0
    public private(set) var isExporting = false
    public private(set) var windowRequest: WindowRequest?

    @ObservationIgnored private let workspace: Workspace
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let fileDialogs: any FileDialogs
    @ObservationIgnored private let copyEntries: CopyEntries
    @ObservationIgnored private let openSource: OpenSource
    @ObservationIgnored private let exportEntries: ExportEntries
    @ObservationIgnored private let filterRecordDelay: Duration
    @ObservationIgnored private let errorAlerts: ErrorAlertController
    @ObservationIgnored private var filterRecorder: FilterHistoryRecorder?
    @ObservationIgnored private var windowRequestCount = 0

    public var title: String {
        workspace.session?.url.lastPathComponent ?? "LogReader"
    }

    public var subtitle: String {
        guard let url = workspace.session?.url, let device = workspace.sidebar.device(containing: url) else { return "" }
        return "\(device.name) · \(device.runtime)"
    }

    public var hasSession: Bool { workspace.session != nil }

    public var entryCount: Int { workspace.session?.content.records.count ?? 0 }

    public var goToEntryPrompt: String { "Entry number (1–\(entryCount))" }

    public var status: StatusBarItem? {
        workspace.session.map { StatusBarItemBuilder.item(for: $0, isExporting: isExporting) }
    }

    public var followSymbolName: String {
        workspace.session?.isFollowing == true ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line.circle"
    }

    public var canFindInEntry: Bool { workspace.session?.primarySelection != nil }

    public var canFindNext: Bool { workspace.session?.findMatches.isEmpty == false }

    public var hasBookmarks: Bool { workspace.session?.bookmarks.isEmpty == false }

    public var hasClearedEntries: Bool { workspace.session?.hasClearedEntries == true }

    public var canClearAroundSelection: Bool { workspace.session?.selectedRecords.count == 1 }

    public var canClearSelection: Bool { workspace.session?.selectedRecords.isEmpty == false }

    public var canOpenSource: Bool {
        guard let session = workspace.session, let record = session.primarySelection else { return false }
        return session.profile.sourceReference(of: record) != nil
    }

    public var openSourceTitle: String {
        "Open Source in \((workspace.session?.profile ?? ProfileRegistry.builtIn).source.editorDisplayName)"
    }

    public var canExport: Bool { isExporting == false && workspace.session?.visible.isEmpty == false }

    public init(
        workspace: Workspace,
        sidebar: SidebarViewModel,
        settings: AppSettings,
        fileDialogs: any FileDialogs,
        copyEntries: CopyEntries,
        openSource: OpenSource,
        exportEntries: ExportEntries,
        attention: any AppAttention,
        filterRecordDelay: Duration = .seconds(3)
    ) {
        self.workspace = workspace
        self.sidebar = sidebar
        self.presets = FilterPresetsViewModel(workspace: workspace, settings: settings)
        self.settings = settings
        self.fileDialogs = fileDialogs
        self.copyEntries = copyEntries
        self.openSource = openSource
        self.exportEntries = exportEntries
        self.filterRecordDelay = filterRecordDelay
        self.errorAlerts = ErrorAlertController(settings: settings, attention: attention)
        sidebar.windowObserver = self
    }

    public func start() {
        errorAlerts.start()
        workspace.observer = self
        workspace.start()
        guard let session = workspace.session, sessionViews?.session !== session else { return }
        rebuildSessionViews(for: session)
    }

    public func stop() {
        sessionViews?.table.stop()
        filterRecorder?.stop()
        errorAlerts.stop()
        workspace.stop()
    }

    public func openFile() {
        guard let url = fileDialogs.chooseLogFile() else { return }
        workspace.openExternal(url)
    }

    public func openExternal(_ url: URL) {
        workspace.openExternal(url)
    }

    public func openInNewWindow(_ url: URL?) {
        windowRequestCount += 1
        windowRequest = WindowRequest(id: windowRequestCount, url: url)
    }

    @discardableResult
    public func openDropped(_ urls: [URL]) -> Bool {
        guard let url = urls.first else { return false }
        workspace.openExternal(url)
        return true
    }

    public func restartDiscovery() {
        workspace.restartDiscovery()
    }

    public func goToEntry(number: Int) {
        workspace.session?.goToEntry(number: number)
    }

    public func requestSearchFocus() {
        searchFocusRequest += 1
    }

    public func requestInspectorSearchFocus() {
        isInspectorPresented = true
        inspectorSearchFocusRequest += 1
    }

    public func toggleInspector() {
        isInspectorPresented.toggle()
    }

    public func showInspector() {
        isInspectorPresented = true
    }

    public func showGoToEntry() {
        isGoToEntryPresented = true
    }

    public func showTimeRange() {
        guard let session = workspace.session else { return }
        let model = TimeRangeViewModel(session: session, settings: settings)
        model.start()
        timeRange = model
        isTimeRangePresented = true
    }

    public func clearAllEntries() {
        workspace.session?.clearAllEntries()
    }

    public func clearEntriesBeforeSelection() {
        workspace.session?.clearEntriesBeforeSelection()
    }

    public func clearEntriesAfterSelection() {
        workspace.session?.clearEntriesAfterSelection()
    }

    public func clearSelectedEntries() {
        workspace.session?.clearSelectedEntries()
    }

    public func restoreAllEntries() {
        workspace.session?.restoreAllEntries()
    }

    public func showSavePreset() {
        presets.showNamePrompt()
    }

    public func showManagePresets() {
        presets.showManage()
    }

    public func jumpToEnd() {
        workspace.session?.jumpToEnd()
    }

    public func copyVisible() {
        guard let session = workspace.session else { return }
        copyEntries.copyVisible(of: session)
    }

    public func exportVisible(format: ExportFormat) async {
        guard let session = workspace.session, isExporting == false else { return }
        isExporting = true
        await exportEntries.export(session, format: format)
        isExporting = false
    }

    public func copySelection() {
        guard let session = workspace.session else { return }
        copyEntries.copySelection(of: session)
    }

    public func openSourceOfSelection() {
        guard let session = workspace.session, let record = session.primarySelection else { return }
        openSource.open(record, profile: session.profile)
    }

    public func findNext() {
        workspace.session?.findNext()
    }

    public func findPrevious() {
        workspace.session?.findPrevious()
    }

    public func toggleBookmark() {
        workspace.session?.toggleBookmarkForSelection()
    }

    public func nextBookmark() {
        workspace.session?.nextBookmark()
    }

    public func previousBookmark() {
        workspace.session?.previousBookmark()
    }

    public func toggleBookmarksOnly() {
        guard let session = workspace.session else { return }
        session.setBookmarksOnly(session.filterState.bookmarksOnly == false)
    }

    public func clearBookmarks() {
        workspace.session?.clearBookmarks()
    }

    public func clearFilters() {
        workspace.session?.clearFilters()
    }
}

// MARK: - WorkspaceObserver

extension MainViewModel: WorkspaceObserver {

    public func workspace(_ workspace: Workspace, didChangeSession session: LogSession) {
        rebuildSessionViews(for: session)
    }
}

// MARK: - SidebarWindowObserver

extension MainViewModel: SidebarWindowObserver {

    public func sidebar(_ sidebar: SidebarViewModel, requestsNewWindowFor url: URL) {
        openInNewWindow(url)
    }
}

// MARK: - Private

private extension MainViewModel {

    func rebuildSessionViews(for session: LogSession) {
        sessionViews?.table.stop()
        filterRecorder?.stop()
        let recorder = FilterHistoryRecorder(session: session, settings: settings, delay: filterRecordDelay)
        recorder.start()
        filterRecorder = recorder
        errorAlerts.attach(to: session)
        let table = LogTablePresenter(
            session: session,
            settings: settings,
            copyEntries: copyEntries,
            openSource: openSource
        )
        table.start()
        sessionViews = SessionViewModels(
            session: session,
            table: table,
            search: SearchViewModel(session: session, settings: settings),
            inspector: EntryInspectorViewModel(
                session: session,
                settings: settings,
                copyEntries: copyEntries,
                openSource: openSource
            ),
            filterMenu: FilterMenuViewModel(session: session, settings: settings),
            chips: FilterChipsViewModel(session: session, settings: settings),
            cleared: ClearedEntriesViewModel(session: session),
            terms: SearchTermsViewModel(session: session)
        )
    }
}
