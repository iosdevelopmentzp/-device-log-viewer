import Foundation

@MainActor
public enum ShortDateTimeText {

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()

    public static func text(for date: Date) -> String {
        formatter.string(from: date)
    }
}
