import Foundation

public enum DeltaTextFormatter {

    public static func text(from previous: TimeInterval?, to current: TimeInterval?) -> String {
        guard let previous, let current else { return "" }
        let seconds = current - previous
        switch abs(seconds) {
        case ..<1:
            return String(format: "+%.0fms", seconds * 1_000)
        case ..<60:
            return String(format: "+%.2fs", seconds)
        default:
            return String(
                format: "+%.0fm%02.0fs",
                (seconds / 60).rounded(.down),
                seconds.truncatingRemainder(dividingBy: 60)
            )
        }
    }
}
