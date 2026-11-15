import Foundation

@MainActor
public protocol FileDialogs: AnyObject {
    func chooseLogFile() -> URL?
    func chooseFolder() -> URL?
    func chooseSaveLocation(suggestedName: String) -> URL?
    func confirm(title: String, message: String, confirmTitle: String) -> Bool
    func present(_ error: any Error)
}
