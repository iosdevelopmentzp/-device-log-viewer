import Foundation

struct LogEntryGrammar: Sendable {

    enum Kind: Sendable {
        case tokens(TokenGrammar)
        case regex(RegexGrammar)
        case json(JSONEntryParser)
    }

    let kind: Kind
    let attributeCount: Int

    var jsonParser: JSONEntryParser? {
        guard case .json(let parser) = kind else { return nil }
        return parser
    }

    init(profile: LogProfile) {
        self.attributeCount = profile.attributes.count
        switch profile.entry {
        case .trailing(let tokens):
            self.kind = .tokens(TokenGrammar(direction: .trailing, tokens: tokens, profile: profile))
        case .leading(let tokens):
            self.kind = .tokens(TokenGrammar(direction: .leading, tokens: tokens, profile: profile))
        case .regex(let pattern):
            if let grammar = RegexGrammar(pattern: pattern, profile: profile) {
                self.kind = .regex(grammar)
            } else {
                self.kind = .tokens(TokenGrammar(direction: .trailing, tokens: [], profile: profile))
            }
        case .json(let rule):
            self.kind = .json(JSONEntryParser(rule: rule, profile: profile))
        }
    }

    func headerLine(_ bytes: UnsafeRawBufferPointer, lineStart: Int, lineEnd: Int) -> LogHeaderLine? {
        switch kind {
        case .tokens(let grammar): grammar.parse(bytes, lineStart: lineStart, lineEnd: lineEnd)
        case .regex(let grammar): grammar.parse(bytes, lineStart: lineStart, lineEnd: lineEnd)
        case .json: nil
        }
    }
}
