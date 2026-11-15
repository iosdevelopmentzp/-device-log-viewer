import LogReaderKit
import SwiftUI

struct UpdateButton: View {

    @Environment(UpdateViewModel.self) private var model
    @State private var isDetailsPresented = false

    var body: some View {
        if let item = model.item {
            content(item)
        }
    }
}

// MARK: - Private

private extension UpdateButton {

    func content(_ item: UpdateButtonItem) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                if item.opensDetails {
                    Button(action: openDetails) {
                        label(item)
                    }
                    .buttonStyle(.plain)
                } else {
                    label(item)
                }
                Spacer(minLength: 0)
                if item.canDismiss {
                    Button(action: model.dismissUpdated) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Hide this message")
                }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .help(item.help)
        }
        .popover(isPresented: $isDetailsPresented, arrowEdge: .top) {
            details(item.kind)
        }
    }

    func label(_ item: UpdateButtonItem) -> some View {
        HStack(spacing: 6) {
            if let symbolName = item.symbolName {
                Image(systemName: symbolName)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(item.title)
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(item.kind == .failed ? Color(nsColor: LogColors.warningText) : Color.primary)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func details(_ kind: UpdateButtonItem.Kind) -> some View {
        switch kind {
        case .available:
            UpdateCommitsPopover(title: model.commitsTitle, commits: model.commits) {
                isDetailsPresented = false
                model.updateNow()
            }
        case .failed:
            UpdateLogPopover(message: model.failureMessage, log: model.logText) {
                isDetailsPresented = false
                model.tryAgain()
            }
        case .running, .upToDate, .updated:
            EmptyView()
        }
    }

    func openDetails() {
        model.openDetails()
        isDetailsPresented = true
    }
}
