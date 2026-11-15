import LogReaderKit
import SwiftUI

struct FilterChipsBar: View {

    let model: FilterChipsViewModel

    var body: some View {
        if model.isEmpty == false {
            content
        }
    }
}

// MARK: - Private

private extension FilterChipsBar {

    var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.chips) { chip in
                            FilterChip(item: chip) { model.remove(chip) }
                        }
                    }
                }
                Button("Clear All", action: model.clearAll)
                    .buttonStyle(.link)
                    .font(.callout)
                    .help("Remove all filters")
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            Divider()
        }
        .background(.bar)
    }
}
