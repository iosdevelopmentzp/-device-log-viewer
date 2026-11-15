import Foundation

public enum JSONTreeBuilder {

    public static let rootKey = "$"

    public static func build(_ json: String, limit: Int) -> JSONTreeNode? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              object is [String: Any] || object is [Any] else { return nil }
        var count = 0
        return node(for: object, id: rootKey, key: rootKey, count: &count, limit: limit)
    }

    public static func subtreeJSON(of node: JSONTreeNode) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: foundationValue(of: node),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
        ) else { return node.valueText }
        return String(decoding: data, as: UTF8.self)
    }

    public static func plainValue(of node: JSONTreeNode) -> String {
        guard node.kind == .string else { return node.valueText }
        return fragment(node.valueText) as? String ?? node.valueText
    }
}

// MARK: - Private

private extension JSONTreeBuilder {

    static func node(for value: Any, id: String, key: String, count: inout Int, limit: Int) -> JSONTreeNode? {
        count += 1
        guard count <= limit else { return nil }
        if let dictionary = value as? [String: Any] {
            var children: [JSONTreeNode] = []
            for childKey in dictionary.keys.sorted() {
                guard let childValue = dictionary[childKey],
                      let child = node(for: childValue, id: id + pathComponent(forKey: childKey), key: childKey, count: &count, limit: limit)
                else { return nil }
                children.append(child)
            }
            return JSONTreeNode(id: id, key: key, valueText: "{\(children.count)}", kind: .object, children: children)
        }
        if let array = value as? [Any] {
            var children: [JSONTreeNode] = []
            for (index, element) in array.enumerated() {
                let elementKey = "[\(index)]"
                guard let child = node(for: element, id: id + elementKey, key: elementKey, count: &count, limit: limit) else { return nil }
                children.append(child)
            }
            return JSONTreeNode(id: id, key: key, valueText: "[\(children.count)]", kind: .array, children: children)
        }
        let scalar = scalarText(value)
        return JSONTreeNode(id: id, key: key, valueText: scalar.text, kind: scalar.kind, children: [])
    }

    static func scalarText(_ value: Any) -> (text: String, kind: JSONValueKind) {
        if value is NSNull {
            return ("null", .null)
        }
        if let string = value as? String {
            return (quoted(string), .string)
        }
        guard let number = value as? NSNumber else { return ("\(value)", .string) }
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return (number.boolValue ? "true" : "false", .bool)
        }
        return (numberText(number), .number)
    }

    static func numberText(_ number: NSNumber) -> String {
        guard CFNumberIsFloatType(number) else { return number.stringValue }
        let double = number.doubleValue
        if double == double.rounded(.down), abs(double) < 9.0e15 {
            return String(Int64(double))
        }
        return number is NSDecimalNumber ? number.stringValue : String(double)
    }

    static func quoted(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed, .withoutEscapingSlashes]) else {
            return "\"\(string)\""
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func pathComponent(forKey key: String) -> String {
        guard isIdentifier(key) else { return "[\(quoted(key))]" }
        return "." + key
    }

    static func isIdentifier(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) == false else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        return key.unicodeScalars.allSatisfy(allowed.contains)
    }

    static func foundationValue(of node: JSONTreeNode) -> Any {
        switch node.kind {
        case .object:
            Dictionary(node.children.map { ($0.key, foundationValue(of: $0)) }, uniquingKeysWith: { first, _ in first })
        case .array:
            node.children.map(foundationValue(of:))
        case .string, .number:
            fragment(node.valueText) ?? node.valueText
        case .bool:
            node.valueText == "true"
        case .null:
            NSNull()
        }
    }

    static func fragment(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
