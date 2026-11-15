import Foundation

public enum LogProfileError: Error, Equatable, Sendable {
    case emptyName
    case noLevels
    case duplicateLevel(String)
    case levelWithoutCodes(String)
    case duplicateAttribute(String)
    case reservedAttribute(String)
    case severalSourceAttributes
    case unknownAttribute(String)
    case unknownTokenReference(String)
    case tokenWithoutAttribute(String)
    case tokenWithoutDelimiters
    case tokenWithoutPrefix
    case tokenWithoutText
    case invalidRegex(String)
    case regexWithoutMessageGroup
    case invalidTimestampFormat(String)
    case unknownTimeZone(String)
    case invalidSeparator
    case invalidFieldIndent
}

// MARK: - LocalizedError

extension LogProfileError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .emptyName: "The profile has no name."
        case .noLevels: "The profile has no levels."
        case .duplicateLevel(let id): "The level id “\(id)” is empty or used twice."
        case .levelWithoutCodes(let id): "The level “\(id)” has no codes."
        case .duplicateAttribute(let id): "The attribute id “\(id)” is empty or used twice."
        case .reservedAttribute(let id): "The attribute id “\(id)” is reserved."
        case .severalSourceAttributes: "Only one attribute can have the role “source”."
        case .unknownAttribute(let id): "A token names the attribute “\(id)”, which does not exist."
        case .unknownTokenReference(let name): "A token requires “\(name)”, which is not a token."
        case .tokenWithoutAttribute(let kind): "A “\(kind)” token needs an attribute."
        case .tokenWithoutDelimiters: "A “delimited” token needs “open” and “close”."
        case .tokenWithoutPrefix: "A “list” token needs a “prefix”."
        case .tokenWithoutText: "A “literal” token needs “text”."
        case .invalidRegex(let message): "The regular expression is not valid: \(message)"
        case .regexWithoutMessageGroup: "The regular expression needs a named group “message”."
        case .invalidTimestampFormat(let format): "The timestamp format “\(format)” is not supported."
        case .unknownTimeZone(let name): "The time zone “\(name)” is unknown."
        case .invalidSeparator: "The separator must be one byte."
        case .invalidFieldIndent: "The field indent must be at least 1."
        }
    }
}
