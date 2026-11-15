import LogReaderKit
import SwiftUI

struct StatusBar: View {

    let model: MainViewModel

    var body: some View {
        if let item = model.status {
            content(item)
        }
    }
}

// MARK: - Private

private extension StatusBar {

    func content(_ item: StatusBarItem) -> some View {
        HStack(spacing: 12) {
            statusIndicator(item.kind)
            Text(item.entriesText)
                .monospacedDigit()
            Text(item.sizeText)
                .foregroundStyle(.secondary)
            if item.isFiltering {
                ProgressView()
                    .controlSize(.small)
            }
            if item.isExporting {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Exporting…")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.isFollowing {
                Label("Following", systemImage: "arrow.down.to.line")
                    .foregroundStyle(.secondary)
                    .help("New entries scroll into view as they arrive. Scroll up to stop.")
            } else {
                Button {
                    model.jumpToEnd()
                } label: {
                    Label(item.jumpTitle, systemImage: "arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut("l", modifiers: .command)
                .help("Scroll to the newest entry and follow new entries (⌘L)")
            }
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    @ViewBuilder
    func statusIndicator(_ kind: StatusBarItem.Kind) -> some View {
        switch kind {
        case .loading:
            Label("Loading", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        case .live:
            Label("Live", systemImage: "circle.fill")
                .foregroundStyle(.green)
                .labelStyle(StatusLabelStyle())
        case .missing:
            Label("File removed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - StatusLabelStyle

private struct StatusLabelStyle: LabelStyle {

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .font(.system(size: 7))
            configuration.title
                .foregroundStyle(.primary)
        }
    }
}
