import Foundation

@MainActor
public enum RelativeTimeText {

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter
    }()

    public static func text(for date: Date, relativeTo now: Date) -> String {
        formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
