import AppKit
import LogReaderKit
import SwiftUI

struct EntryTextView: NSViewRepresentable {

    let text: NSAttributedString
    let links: [EntryTextLink]
    let focusRange: NSRange?
    let onDoubleClickWord: (String) -> Void
    let onSearchInLog: (String) -> Void
    let searchInLogTitle: (String) -> String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = LogColors.background
        let textView = EntryNSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = LogColors.background
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.linkTextAttributes = TextStyleSheet.linkAttributes
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EntryNSTextView else { return }
        textView.onDoubleClickWord = onDoubleClickWord
        textView.onSearchInLog = onSearchInLog
        textView.searchInLogTitle = searchInLogTitle
        let linkedText = linkedText()
        if textView.textStorage?.isEqual(to: linkedText) == false {
            textView.textStorage?.setAttributedString(linkedText)
            context.coordinator.lastFocusRange = nil
            if focusRange == nil {
                textView.scrollToBeginningOfDocument(nil)
            }
        }
        guard let focusRange, focusRange != context.coordinator.lastFocusRange else { return }
        context.coordinator.lastFocusRange = focusRange
        guard NSMaxRange(focusRange) <= (textView.textStorage?.length ?? 0) else { return }
        textView.setSelectedRange(focusRange)
        textView.scrollRangeToVisible(focusRange)
        textView.showFindIndicator(for: focusRange)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        guard let textView = scrollView.documentView as? EntryNSTextView else { return }
        textView.onDoubleClickWord = nil
        textView.onSearchInLog = nil
        textView.searchInLogTitle = nil
    }
}

// MARK: - Coordinator

extension EntryTextView {

    final class Coordinator {
        var lastFocusRange: NSRange?
    }
}

// MARK: - Private

private extension EntryTextView {

    func linkedText() -> NSAttributedString {
        guard links.isEmpty == false else { return text }
        let result = NSMutableAttributedString(attributedString: text)
        for link in links where NSMaxRange(link.range) <= result.length {
            result.addAttributes([.link: link.url, .cursor: NSCursor.pointingHand], range: link.range)
        }
        return result
    }
}
