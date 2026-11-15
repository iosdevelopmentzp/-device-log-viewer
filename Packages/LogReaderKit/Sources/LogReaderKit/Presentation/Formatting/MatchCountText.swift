public enum MatchCountText {

    public static func text(for result: FileSearchResult?) -> String {
        switch result {
        case .count(1): "1 match"
        case let .count(count): "\(count) matches"
        case .skipped: "skipped"
        case nil: ""
        }
    }
}
