import LogReaderKit
import SwiftUI

struct ClearedEntriesBanner: View {

    let model: ClearedEntriesViewModel

    var body: some View {
        if model.isActive {
            content
        }
    }
}

// MARK: - Private

private extension ClearedEntriesBanner {

    var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .foregroundStyle(Color(nsColor: LogColors.warningText))
                Text(model.summaryText)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .fixedSize()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.parts) { part in
                            ClearedPartChip(item: part) { model.restore(part: part) }
                        }
                    }
                }
                Spacer(minLength: 0)
                Button("Restore All", action: model.restoreAll)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color(nsColor: LogColors.warningText))
                    .help("Show every cleared entry again")
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color(nsColor: LogColors.clearedBannerBackground))
            Divider()
        }
        .background(.bar)
    }
}
