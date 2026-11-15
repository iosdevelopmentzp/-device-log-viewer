import Foundation

@MainActor
public protocol AppearanceApplier: AnyObject {
    func apply(_ appearance: Appearance)
}
