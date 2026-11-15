import AppKit

final class EntryNSTextView: NSTextView {

    var onDoubleClickWord: ((String) -> Void)?
    var onSearchInLog: ((String) -> Void)?
    var searchInLogTitle: ((String) -> String)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard event.clickCount == 2 else { return }
        let word = selectedText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard word.isEmpty == false, word.contains(where: \.isNewline) == false else { return }
        onDoubleClickWord?(word)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let text = selectedText
        guard text.isEmpty == false, let onSearchInLog, let searchInLogTitle else { return menu }
        menu.insertItem(ClosureMenuItem(title: searchInLogTitle(text)) { onSearchInLog(text) }, at: 0)
        menu.insertItem(.separator(), at: 1)
        return menu
    }
}

// MARK: - Private

private extension EntryNSTextView {

    var selectedText: String {
        let range = selectedRange()
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return "" }
        return (string as NSString).substring(with: range)
    }
}
