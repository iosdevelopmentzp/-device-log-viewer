import Foundation
import LogReaderCore

public extension SearchScope {

    static func displayName(ofID id: String, in profile: LogProfile) -> String {
        switch id {
        case messageID: "Message and fields"
        case levelID: "Level"
        default: profile.attribute(id: id)?.title ?? id
        }
    }

    func summary(in profile: LogProfile) -> String {
        sorted(in: profile)
            .map { Self.displayName(ofID: $0, in: profile) }
            .joined(separator: ", ")
    }
}
