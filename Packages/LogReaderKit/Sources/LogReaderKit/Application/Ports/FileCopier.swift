import Foundation

public protocol FileCopier: AnyObject {
    func copy(_ url: URL, to destination: URL, replacing: Bool) throws
}
