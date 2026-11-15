import Foundation

@MainActor
public protocol AppAttentionObserver: AnyObject {
    func appDidBecomeActive()
}
