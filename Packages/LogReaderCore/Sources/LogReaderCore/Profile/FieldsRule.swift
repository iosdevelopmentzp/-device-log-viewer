import Foundation

public struct FieldsRule: Codable, Sendable, Equatable {

    public var indent: Int

    public static let standard = FieldsRule(indent: 2)

    public init(indent: Int) {
        self.indent = indent
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.indent = try container.decodeIfPresent(Int.self, forKey: .indent) ?? Self.standard.indent
    }
}
