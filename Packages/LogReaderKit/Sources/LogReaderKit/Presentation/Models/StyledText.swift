import Foundation

public struct StyledText: Sendable, Equatable {

    public struct Span: Sendable, Equatable {
        public let range: NSRange
        public let style: TextStyle

        public init(range: NSRange, style: TextStyle) {
            self.range = range
            self.style = style
        }
    }

    public let string: String
    public let spans: [Span]

    public init(string: String, spans: [Span]) {
        self.string = string
        self.spans = spans
    }
}
