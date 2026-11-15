import LogReaderKit

@MainActor
final class FakeAppAttention: AppAttention {

    var isAppActive = false
    weak var observer: (any AppAttentionObserver)?
    private(set) var attentionRequests = 0
    private(set) var badges: [String?] = []

    func requestAttention() {
        attentionRequests += 1
    }

    func setBadge(_ text: String?) {
        badges.append(text)
    }

    func simulateActivation() {
        isAppActive = true
        observer?.appDidBecomeActive()
    }
}
