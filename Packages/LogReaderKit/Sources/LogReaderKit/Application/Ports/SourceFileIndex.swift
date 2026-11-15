import Foundation

public protocol SourceFileIndex: AnyObject {
    func locate(fileName: String, under root: URL, preferredExtension: String) -> [URL]
}
