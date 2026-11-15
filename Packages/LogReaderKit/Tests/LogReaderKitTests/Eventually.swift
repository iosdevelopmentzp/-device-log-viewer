import Foundation
import Testing

@MainActor
enum Eventually {

    private static let timeout: Duration = .seconds(2)
    private static let step: Duration = .milliseconds(5)

    static func wait(until condition: () -> Bool) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while condition() == false {
            guard clock.now < deadline else {
                Issue.record("Condition not met in \(timeout)")
                return
            }
            try? await Task.sleep(for: step)
        }
    }
}
