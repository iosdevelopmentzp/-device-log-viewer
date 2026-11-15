import Foundation
import LogReaderKit

@MainActor
final class FakeFileDialogs: FileDialogs {

    struct Confirmation: Equatable {
        let title: String
        let message: String
        let confirmTitle: String
    }

    var fileToChoose: URL?
    var folderToChoose: URL?
    var saveLocation: URL?
    var confirmAnswer = false
    private(set) var suggestedNames: [String] = []
    private(set) var confirmations: [Confirmation] = []
    private(set) var presentedErrors: [any Error] = []

    func chooseLogFile() -> URL? {
        fileToChoose
    }

    func chooseFolder() -> URL? {
        folderToChoose
    }

    func chooseSaveLocation(suggestedName: String) -> URL? {
        suggestedNames.append(suggestedName)
        return saveLocation
    }

    func confirm(title: String, message: String, confirmTitle: String) -> Bool {
        confirmations.append(Confirmation(title: title, message: message, confirmTitle: confirmTitle))
        return confirmAnswer
    }

    func present(_ error: any Error) {
        presentedErrors.append(error)
    }
}
