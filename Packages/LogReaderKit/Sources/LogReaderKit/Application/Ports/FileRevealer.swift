import Foundation

@MainActor
public protocol FileRevealer: AnyObject {
    func reveal(_ url: URL)
    func open(_ url: URL)
}
