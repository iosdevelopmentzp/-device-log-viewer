import Foundation

public protocol FileTrasher: AnyObject {
    func trash(_ url: URL) throws
}
