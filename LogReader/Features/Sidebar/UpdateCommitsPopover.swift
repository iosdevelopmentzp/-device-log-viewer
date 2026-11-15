import LogReaderKit
import SwiftUI

struct UpdateCommitsPopover: View {

    let title: String
    let commits: [UpdateCommit]
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(commits) { commit in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(commit.shortHash)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(commit.subject)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
            HStack {
                Spacer()
                Button("Update Now", action: onUpdate)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .help("Build the new commits and install them. The app closes for a few seconds and opens again.")
            }
        }
        .padding(14)
        .frame(width: 380)
    }
}
