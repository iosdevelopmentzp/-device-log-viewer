import Foundation

enum GitAppUpdaterError: Error {
    case notInstalled
    case timedOut
    case failed(status: Int32)
}
