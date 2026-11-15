import LogReaderKit
import SwiftUI

struct MainView: View {

    @State private var model: MainViewModel
    private let appearanceApplier: any AppearanceApplier
    private let initialURL: URL?

    @Environment(SettingsViewModel.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @FocusState private var isSearchFocused: Bool

    init(model: MainViewModel, appearanceApplier: any AppearanceApplier, initialURL: URL?) {
        _model = State(initialValue: model)
        self.appearanceApplier = appearanceApplier
        self.initialURL = initialURL
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model.sidebar)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            detail
        }
        .inspector(isPresented: $model.isInspectorPresented) {
            inspector
                .inspectorColumnWidth(min: 280, ideal: 420, max: 900)
        }
        .toolbar { toolbarContent }
        .background { ToolbarTooltips(tips: toolbarTips) }
        .navigationTitle(model.title)
        .navigationSubtitle(model.subtitle)
        .focusedSceneValue(\.mainViewModel, model)
        .dropDestination(for: URL.self) { urls, _ in
            model.openDropped(urls)
        }
        .sheet(isPresented: $model.isGoToEntryPresented) {
            if model.hasSession {
                GoToEntrySheet(prompt: model.goToEntryPrompt, onGo: model.goToEntry(number:))
            }
        }
        .sheet(isPresented: $model.isTimeRangePresented) {
            if let timeRange = model.timeRange {
                TimeRangeSheet(model: timeRange)
            }
        }
        .sheet(isPresented: Bindable(model.presets).isNamePromptPresented) {
            PresetNameSheet(model: model.presets)
        }
        .sheet(isPresented: Bindable(model.presets).isManagePresented) {
            ManagePresetsSheet(model: model.presets)
        }
        .onChange(of: model.searchFocusRequest) {
            isSearchFocused = true
        }
        .onChange(of: settings.showsConnectedDevices) {
            model.restartDiscovery()
        }
        .onChange(of: settings.appearance) {
            appearanceApplier.apply(settings.appearance)
        }
        .onChange(of: model.windowRequest) { _, request in
            guard let request else { return }
            if let url = request.url {
                openWindow(id: "main", value: url)
            } else {
                openWindow(id: "main")
            }
        }
        .task {
            appearanceApplier.apply(settings.appearance)
            model.start()
            guard let initialURL else { return }
            model.openExternal(initialURL)
        }
        .onDisappear {
            model.stop()
        }
    }
}

// MARK: - Private

private extension MainView {

    static let followTitle = "Follow"
    static let inspectorTitle = "Inspector"

    @ViewBuilder
    var detail: some View {
        if let views = model.sessionViews {
            LogTableView(
                presenter: views.table,
                fontSize: settings.fontSize,
                timeZoneMode: settings.timeZoneMode,
                hiddenColumns: settings.hiddenColumns,
                rowDensity: settings.rowDensity,
                fontFamily: settings.fontFamily,
                expandsRows: settings.expandsRows,
                collapsesRepeats: settings.collapsesRepeats,
                onToggleInspector: model.toggleInspector,
                onShowInspector: model.showInspector
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    ClearedEntriesBanner(model: views.cleared)
                    FilterChipsBar(model: views.chips)
                    SearchTermsBar(model: views.terms)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatusBar(model: model)
            }
        } else {
            ContentUnavailableView(
                "Select a Log File",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Pick a file in the sidebar, drop a file here, or press ⌘O.")
            )
        }
    }

    @ViewBuilder
    var inspector: some View {
        if let views = model.sessionViews {
            EntryInspectorView(model: views.inspector, searchFocusRequest: model.inspectorSearchFocusRequest)
        } else {
            Color.clear
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        if let views = model.sessionViews {
            ToolbarItem(placement: .principal) {
                SearchBar(model: views.search, isFocused: $isSearchFocused)
            }
            ToolbarItem {
                FilterMenu(model: views.filterMenu, presets: model.presets, onTimeRange: model.showTimeRange)
            }
            ToolbarItem {
                Button(action: settings.toggleExpandRows) {
                    Label(settings.expandRowsTitle, systemImage: settings.expandRowsSymbolName)
                }
            }
            ToolbarItem {
                Button(action: settings.toggleCollapsesRepeats) {
                    Label(settings.collapseRepeatsTitle, systemImage: settings.collapseRepeatsSymbolName)
                }
            }
            ToolbarItem {
                Button(action: model.jumpToEnd) {
                    Label(Self.followTitle, systemImage: model.followSymbolName)
                }
            }
        }
        ToolbarItem {
            ThemeMenu()
        }
        ToolbarItem {
            Button(action: model.toggleInspector) {
                Label(Self.inspectorTitle, systemImage: "sidebar.right")
            }
        }
    }

    var toolbarTips: [String: String] {
        [
            settings.expandRowsTitle: settings.expandRowsHelp,
            settings.collapseRepeatsTitle: settings.collapseRepeatsHelp,
            Self.followTitle: "Scroll to the newest entry and follow new entries (⌘L)",
            Self.inspectorTitle: "Show or hide the entry details (Space)"
        ]
    }
}
