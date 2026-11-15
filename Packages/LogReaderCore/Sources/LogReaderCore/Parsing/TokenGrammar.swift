import Foundation

struct TokenGrammar: Sendable {

    enum Direction: Sendable {
        case trailing
        case leading
    }

    fileprivate struct CompiledToken: Sendable {
        let token: EntryToken
        let attributeIndex: Int?
        let attributeIsList: Bool
        let open: [UInt8]
        let close: [UInt8]
        let prefix: [UInt8]
        let text: [UInt8]
        let requiresIndex: Int?
    }

    fileprivate struct State {
        var level: LogLevel?
        var timestamp: TimeInterval?
        var attributes: [AttributeValue] = []
        var found: UInt64 = 0
        var pending: [(token: Int, position: Int)] = []
        var position: Int

        func isFound(_ token: Int) -> Bool {
            found & (1 << UInt64(token)) != 0
        }

        mutating func setFound(_ token: Int, _ value: Bool) {
            if value {
                found |= 1 << UInt64(token)
            } else {
                found &= ~(1 << UInt64(token))
            }
        }

        mutating func setAttribute(_ index: Int, _ value: AttributeValue, count: Int) {
            if attributes.isEmpty {
                attributes = Array(repeating: .none, count: count)
            }
            attributes[index] = value
        }
    }

    private let direction: Direction
    private let tokens: [CompiledToken]
    private let time: TimeValueParser
    private let levels: LevelMatcher
    private let attributeCount: Int
    private let hasTimeOrLevel: Bool

    init(direction: Direction, tokens: [EntryToken], profile: LogProfile) {
        let names = tokens.map(\.name)
        self.direction = direction
        self.tokens = tokens.map { token in
            CompiledToken(
                token: token,
                attributeIndex: token.attribute.flatMap(profile.attributeIndex(id:)),
                attributeIsList: token.attribute.flatMap(profile.attribute(id:))?.kind == .list,
                open: Array((token.open ?? "").utf8),
                close: Array((token.close ?? "").utf8),
                prefix: Array((token.prefix ?? "").utf8),
                text: Array((token.text ?? "").trimmingCharacters(in: .whitespaces).utf8),
                requiresIndex: token.requires.flatMap { name in names.firstIndex { $0 == name } }
            )
        }
        self.time = TimeValueParser(rule: profile.timestamp)
        self.levels = LevelMatcher(levels: profile.levels)
        self.attributeCount = profile.attributes.count
        self.hasTimeOrLevel = tokens.contains { $0.kind == .time || $0.kind == .level }
    }

    func parse(_ bytes: UnsafeRawBufferPointer, lineStart: Int, lineEnd: Int) -> LogHeaderLine? {
        let lineEnd = Self.trimmedEnd(bytes, lineStart: lineStart, end: lineEnd)
        var state = State(position: direction == .trailing ? lineEnd : Self.skippingSpaces(bytes, from: lineStart, to: lineEnd))
        for index in tokens.indices {
            let compiled = tokens[index]
            if let requires = compiled.requiresIndex, requires < index, state.isFound(requires) == false {
                continue
            }
            let before = state.position
            let matched = match(compiled, bytes: bytes, lineStart: lineStart, lineEnd: lineEnd, state: &state)
            if matched {
                state.setFound(index, true)
                if let requires = compiled.requiresIndex, requires > index {
                    state.pending.append((index, before))
                }
                state.pending.removeAll { $0.token != index && tokens[$0.token].requiresIndex == index }
            } else {
                guard compiled.token.required == false else { return nil }
                rollBack(dependentsOf: index, state: &state)
            }
        }
        let recognized = hasTimeOrLevel ? (state.level != nil || state.timestamp != nil) : state.found != 0
        guard recognized else { return nil }
        if state.attributes.isEmpty, attributeCount > 0 {
            state.attributes = Array(repeating: .none, count: attributeCount)
        }
        let messageRange: Range<Int>
        let metadataRange: Range<Int>
        switch direction {
        case .trailing:
            messageRange = lineStart..<state.position
            metadataRange = state.position..<lineEnd
        case .leading:
            messageRange = state.position..<lineEnd
            metadataRange = lineStart..<state.position
        }
        return LogHeaderLine(
            level: state.level,
            timestamp: state.timestamp,
            attributes: state.attributes,
            messageRange: messageRange,
            metadataRange: metadataRange
        )
    }
}

// MARK: - Private

private extension TokenGrammar {

    func rollBack(dependentsOf index: Int, state: inout State) {
        let dependents = state.pending.filter { tokens[$0.token].requiresIndex == index }
        guard let earliest = dependents.min(by: { $0.token < $1.token }) else { return }
        state.position = earliest.position
        for token in earliest.token..<index {
            state.setFound(token, false)
            clearValue(of: tokens[token], state: &state)
        }
        state.pending.removeAll { $0.token >= earliest.token && $0.token < index }
    }

    func clearValue(of compiled: CompiledToken, state: inout State) {
        switch compiled.token.kind {
        case .time: state.timestamp = nil
        case .level: state.level = nil
        case .delimited, .word, .list:
            if let attributeIndex = compiled.attributeIndex, state.attributes.isEmpty == false { state.attributes[attributeIndex] = .none }
        case .literal: break
        }
    }

    func match(_ compiled: CompiledToken, bytes: UnsafeRawBufferPointer, lineStart: Int, lineEnd: Int, state: inout State) -> Bool {
        switch direction {
        case .trailing: matchTrailing(compiled, bytes: bytes, lineStart: lineStart, state: &state)
        case .leading: matchLeading(compiled, bytes: bytes, lineEnd: lineEnd, state: &state)
        }
    }

    func matchTrailing(_ compiled: CompiledToken, bytes: UnsafeRawBufferPointer, lineStart: Int, state: inout State) -> Bool {
        let end = state.position
        switch compiled.token.kind {
        case .time:
            guard let range = trailingValueRange(compiled, bytes: bytes, lineStart: lineStart, end: end, fixedWidth: time.fixedWidth),
                  let value = time.parse(bytes, range: range) else { return false }
            state.timestamp = value
            state.position = Self.trimmedEnd(bytes, lineStart: lineStart, end: range.lowerBound - compiled.open.count)
            return true
        case .level:
            guard let range = trailingValueRange(compiled, bytes: bytes, lineStart: lineStart, end: end, fixedWidth: nil),
                  let level = levels.level(bytes, range: range) else { return false }
            state.level = level
            state.position = Self.trimmedEnd(bytes, lineStart: lineStart, end: range.lowerBound - compiled.open.count)
            return true
        case .delimited:
            guard let inner = Self.trailingDelimited(bytes, lineStart: lineStart, end: end, open: compiled.open, close: compiled.close),
                  Self.matches(compiled.token.pattern, bytes: bytes, range: inner) else { return false }
            setText(compiled, Self.string(bytes, range: inner), state: &state)
            state.position = Self.trimmedEnd(bytes, lineStart: lineStart, end: inner.lowerBound - compiled.open.count)
            return true
        case .word:
            let word = Self.lastWord(bytes, lineStart: lineStart, end: end)
            guard word.isEmpty == false else { return false }
            setText(compiled, Self.string(bytes, range: word), state: &state)
            state.position = Self.trimmedEnd(bytes, lineStart: lineStart, end: word.lowerBound)
            return true
        case .list:
            var values: [String] = []
            var position = end
            while position > lineStart {
                let word = Self.lastWord(bytes, lineStart: lineStart, end: position)
                guard word.count > compiled.prefix.count, Self.hasPrefix(bytes, range: word, prefix: compiled.prefix) else { break }
                values.append(Self.string(bytes, range: (word.lowerBound + compiled.prefix.count)..<word.upperBound))
                position = Self.trimmedEnd(bytes, lineStart: lineStart, end: word.lowerBound)
            }
            guard values.isEmpty == false, let attributeIndex = compiled.attributeIndex else { return false }
            state.setAttribute(attributeIndex, .list(values.reversed()), count: attributeCount)
            state.position = position
            return true
        case .literal:
            let start = end - compiled.text.count
            guard start >= lineStart, Self.equals(bytes, at: start, compiled.text) else { return false }
            state.position = Self.trimmedEnd(bytes, lineStart: lineStart, end: start)
            return true
        }
    }

    func matchLeading(_ compiled: CompiledToken, bytes: UnsafeRawBufferPointer, lineEnd: Int, state: inout State) -> Bool {
        let start = state.position
        switch compiled.token.kind {
        case .time:
            guard let range = leadingValueRange(compiled, bytes: bytes, start: start, lineEnd: lineEnd, fixedWidth: time.fixedWidth),
                  let value = time.parse(bytes, range: range) else { return false }
            state.timestamp = value
            state.position = Self.skippingSpaces(bytes, from: range.upperBound + compiled.close.count, to: lineEnd)
            return true
        case .level:
            guard let range = leadingValueRange(compiled, bytes: bytes, start: start, lineEnd: lineEnd, fixedWidth: nil),
                  let level = levels.level(bytes, range: range) else { return false }
            state.level = level
            state.position = Self.skippingSpaces(bytes, from: range.upperBound + compiled.close.count, to: lineEnd)
            return true
        case .delimited:
            guard let inner = Self.leadingDelimited(bytes, start: start, lineEnd: lineEnd, open: compiled.open, close: compiled.close),
                  Self.matches(compiled.token.pattern, bytes: bytes, range: inner) else { return false }
            setText(compiled, Self.string(bytes, range: inner), state: &state)
            state.position = Self.skippingSpaces(bytes, from: inner.upperBound + compiled.close.count, to: lineEnd)
            return true
        case .word:
            let word = Self.firstWord(bytes, start: start, lineEnd: lineEnd)
            guard word.isEmpty == false else { return false }
            setText(compiled, Self.string(bytes, range: word), state: &state)
            state.position = Self.skippingSpaces(bytes, from: word.upperBound, to: lineEnd)
            return true
        case .list:
            var values: [String] = []
            var position = start
            while position < lineEnd {
                let word = Self.firstWord(bytes, start: position, lineEnd: lineEnd)
                guard word.count > compiled.prefix.count, Self.hasPrefix(bytes, range: word, prefix: compiled.prefix) else { break }
                values.append(Self.string(bytes, range: (word.lowerBound + compiled.prefix.count)..<word.upperBound))
                position = Self.skippingSpaces(bytes, from: word.upperBound, to: lineEnd)
            }
            guard values.isEmpty == false, let attributeIndex = compiled.attributeIndex else { return false }
            state.setAttribute(attributeIndex, .list(values), count: attributeCount)
            state.position = position
            return true
        case .literal:
            guard start + compiled.text.count <= lineEnd, Self.equals(bytes, at: start, compiled.text) else { return false }
            state.position = Self.skippingSpaces(bytes, from: start + compiled.text.count, to: lineEnd)
            return true
        }
    }

    func trailingValueRange(_ compiled: CompiledToken, bytes: UnsafeRawBufferPointer, lineStart: Int, end: Int, fixedWidth: Int?) -> Range<Int>? {
        if compiled.open.isEmpty == false {
            return Self.trailingDelimited(bytes, lineStart: lineStart, end: end, open: compiled.open, close: compiled.close)
        }
        if let fixedWidth {
            let start = end - fixedWidth
            guard start >= lineStart, Self.isBoundary(bytes, lineStart: lineStart, at: start) else { return nil }
            return start..<end
        }
        let word = Self.lastWord(bytes, lineStart: lineStart, end: end)
        return word.isEmpty ? nil : word
    }

    func leadingValueRange(_ compiled: CompiledToken, bytes: UnsafeRawBufferPointer, start: Int, lineEnd: Int, fixedWidth: Int?) -> Range<Int>? {
        if compiled.open.isEmpty == false {
            return Self.leadingDelimited(bytes, start: start, lineEnd: lineEnd, open: compiled.open, close: compiled.close)
        }
        if let fixedWidth {
            guard start + fixedWidth <= lineEnd, Self.isWordEnd(bytes, at: start + fixedWidth, lineEnd: lineEnd) else { return nil }
            return start..<(start + fixedWidth)
        }
        let word = Self.firstWord(bytes, start: start, lineEnd: lineEnd)
        return word.isEmpty ? nil : word
    }

    func setText(_ compiled: CompiledToken, _ value: String, state: inout State) {
        guard let attributeIndex = compiled.attributeIndex else { return }
        state.setAttribute(attributeIndex, compiled.attributeIsList ? .list([value]) : .text(value), count: attributeCount)
    }

    static func matches(_ pattern: EntryToken.Pattern?, bytes: UnsafeRawBufferPointer, range: Range<Int>) -> Bool {
        guard range.isEmpty == false else { return false }
        switch pattern {
        case nil:
            return true
        case .fileLine:
            var index = range.upperBound - 1
            var digitCount = 0
            while index >= range.lowerBound, bytes[index].isDigit {
                digitCount += 1
                index -= 1
            }
            guard digitCount > 0, index > range.lowerBound else { return false }
            return bytes[index] == UInt8(ascii: ":")
        }
    }

    static func trailingDelimited(_ bytes: UnsafeRawBufferPointer, lineStart: Int, end: Int, open: [UInt8], close: [UInt8]) -> Range<Int>? {
        let closeStart = end - close.count
        guard closeStart - lineStart >= open.count, equals(bytes, at: closeStart, close) else { return nil }
        var index = closeStart - open.count
        while index >= lineStart {
            if equals(bytes, at: index, open) {
                guard isBoundary(bytes, lineStart: lineStart, at: index) else { return nil }
                let inner = (index + open.count)..<closeStart
                return inner.isEmpty ? nil : inner
            }
            if index + close.count <= closeStart, equals(bytes, at: index, close) { return nil }
            index -= 1
        }
        return nil
    }

    static func leadingDelimited(_ bytes: UnsafeRawBufferPointer, start: Int, lineEnd: Int, open: [UInt8], close: [UInt8]) -> Range<Int>? {
        guard start + open.count <= lineEnd, equals(bytes, at: start, open) else { return nil }
        let innerStart = start + open.count
        var index = innerStart
        while index + close.count <= lineEnd {
            if equals(bytes, at: index, close) {
                guard index > innerStart, isWordEnd(bytes, at: index + close.count, lineEnd: lineEnd) else { return nil }
                return innerStart..<index
            }
            guard equals(bytes, at: index, open) == false else { return nil }
            index += 1
        }
        return nil
    }

    static func equals(_ bytes: UnsafeRawBufferPointer, at start: Int, _ expected: [UInt8]) -> Bool {
        guard expected.isEmpty == false, start >= 0, start + expected.count <= bytes.count else { return false }
        for (offset, byte) in expected.enumerated() where bytes[start + offset] != byte {
            return false
        }
        return true
    }

    static func hasPrefix(_ bytes: UnsafeRawBufferPointer, range: Range<Int>, prefix: [UInt8]) -> Bool {
        range.count >= prefix.count && equals(bytes, at: range.lowerBound, prefix)
    }

    static func lastWord(_ bytes: UnsafeRawBufferPointer, lineStart: Int, end: Int) -> Range<Int> {
        var start = end
        while start > lineStart, bytes[start - 1] != .space {
            start -= 1
        }
        return start..<end
    }

    static func firstWord(_ bytes: UnsafeRawBufferPointer, start: Int, lineEnd: Int) -> Range<Int> {
        var end = start
        while end < lineEnd, bytes[end] != .space {
            end += 1
        }
        return start..<end
    }

    static func isBoundary(_ bytes: UnsafeRawBufferPointer, lineStart: Int, at index: Int) -> Bool {
        index == lineStart || bytes[index - 1] == .space
    }

    static func isWordEnd(_ bytes: UnsafeRawBufferPointer, at index: Int, lineEnd: Int) -> Bool {
        index >= lineEnd || bytes[index] == .space
    }

    static func trimmedEnd(_ bytes: UnsafeRawBufferPointer, lineStart: Int, end: Int) -> Int {
        var result = end
        while result > lineStart, bytes[result - 1] == .space || bytes[result - 1] == .carriageReturn {
            result -= 1
        }
        return result
    }

    static func skippingSpaces(_ bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> Int {
        var result = start
        while result < end, bytes[result] == .space {
            result += 1
        }
        return result
    }

    static func string(_ bytes: UnsafeRawBufferPointer, range: Range<Int>) -> String {
        String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range]), as: UTF8.self)
    }
}
