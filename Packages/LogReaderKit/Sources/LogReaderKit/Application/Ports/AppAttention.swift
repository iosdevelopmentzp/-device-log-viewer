import Foundation

@MainActor
public protocol AppAttention: AnyObject {
    var isAppActive: Bool { get }
    var observer: (any AppAttentionObserver)? { get set }
    func requestAttention()
    func setBadge(_ text: String?)
}
