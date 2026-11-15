import SwiftUI

struct UpdateLogPopover: View {

    let message: String
    let log: String
    let onTryAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.headline)
            ScrollView([.vertical, .horizontal]) {
                Text(log)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
            .defaultScrollAnchor(.bottom)
            .frame(height: 320)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            HStack {
                Spacer()
                Button("Try Again", action: onTryAgain)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 560)
    }
}
