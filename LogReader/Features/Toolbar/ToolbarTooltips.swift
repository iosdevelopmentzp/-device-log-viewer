import SwiftUI

struct ToolbarTooltips: NSViewRepresentable {

    let tips: [String: String]

    func makeNSView(context: Context) -> ToolbarTooltipsView {
        ToolbarTooltipsView()
    }

    func updateNSView(_ view: ToolbarTooltipsView, context: Context) {
        view.tips = tips
    }
}
