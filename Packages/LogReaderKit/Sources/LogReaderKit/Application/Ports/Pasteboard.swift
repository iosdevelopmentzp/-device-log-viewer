import Foundation

@MainActor
public protocol Pasteboard: AnyObject {
    func write(text: String)
    func write(fileURL: URL)
}
