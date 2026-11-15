import LogReaderKit
import SwiftUI

struct SidebarView: View {

    @Bindable var model: SidebarViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            UpdateButton()
        }
    }
}

// MARK: - Private

private extension SidebarView {

    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(model.queryPrompt, text: $model.query, prompt: Text(model.queryPrompt))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onExitCommand { model.clearQuery() }
                    .overlay(alignment: .trailing) {
                        if model.query.isEmpty == false {
                            Button {
                                model.clearQuery()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                            .help("Clear the filter")
                        }
                    }
                Toggle(isOn: $model.searchesContents) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Search inside files")
                if model.isSearchingContents {
                    ProgressView()
                        .controlSize(.small)
                }
                Toggle(isOn: $model.showsBootedOnly) {
                    Image(systemName: "power")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Show only running simulators")
            }
            if model.bootedCountText.isEmpty == false {
                Text(model.bootedCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    var list: some View {
        List(selection: $model.selectedFileID) {
            if model.openedFiles.isEmpty == false {
                Section("Opened Files") {
                    ForEach(model.openedFiles) { file in
                        Label(file.title, systemImage: "doc.text")
                            .lineLimit(1)
                            .tag(file.id)
                            .contextMenu {
                                LogFileContextMenu(item: file, model: model, showsRemoveFromList: true)
                            }
                    }
                }
            }
            ForEach(model.devices) { device in
                Section {
                    ForEach(device.apps) { app in
                        appGroup(app)
                    }
                } header: {
                    DeviceHeader(item: device)
                        .contextMenu { DeviceContextMenu(item: device, model: model) }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if model.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "iphone.slash",
                    description: Text(model.emptyText)
                )
            } else if model.showsNoRunningSimulators {
                ContentUnavailableView {
                    Label("No Running Simulators", systemImage: "power")
                } description: {
                    Text("Only running simulators are shown.")
                } actions: {
                    Button("Show All Simulators", action: model.showAllSimulators)
                }
            } else if model.showsNoContentMatches {
                ContentUnavailableView(
                    "No Matches in Files",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No file of the shown apps contains the text.")
                )
            } else if model.showsNoMatches {
                ContentUnavailableView.search(text: model.query)
            }
        }
    }

    func appGroup(_ app: SidebarAppItem) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(for: app.id)) {
            ForEach(app.files) { file in
                FileRow(item: file)
                    .tag(file.id)
                    .contextMenu {
                        LogFileContextMenu(item: file, model: model, showsRemoveFromList: false)
                    }
            }
        } label: {
            Label(app.bundleID, systemImage: "app.dashed")
                .lineLimit(1)
                .contextMenu { AppContainerContextMenu(item: app, model: model) }
        }
    }

    func expandedBinding(for appID: String) -> Binding<Bool> {
        Binding(
            get: { model.isExpanded(appID: appID) },
            set: { model.setExpanded($0, appID: appID) }
        )
    }
}
