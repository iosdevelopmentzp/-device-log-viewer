import Foundation

struct ZoneOffset: Sendable {

    private let fixedOffset: Int?
    private let zone: TimeZone

    init(identifier: String) {
        let zone = TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0)!
        self.zone = zone
        self.fixedOffset = zone.nextDaylightSavingTimeTransition == nil ? zone.secondsFromGMT() : nil
    }

    func secondsFromGMT(forLocal seconds: Int) -> Int {
        if let fixedOffset { return fixedOffset }
        return zone.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}
