import Foundation
import LogReaderCore

public extension FacetColumn {

    func displayName(in profile: LogProfile) -> String {
        guard let id = attributeID else { return "Level" }
        return profile.attribute(id: id)?.title ?? id
    }

    func columnTitle(in profile: LogProfile) -> String {
        displayName(in: profile)
    }

    func valuePrefix(in profile: LogProfile) -> String {
        attributeID.flatMap(profile.attribute(id:))?.prefix ?? ""
    }
}
