import Foundation

public enum GroupedNumberText {

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = " "
        formatter.groupingSize = 3
        return formatter
    }()

    public static func text(_ number: Int) -> String {
        formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
}
