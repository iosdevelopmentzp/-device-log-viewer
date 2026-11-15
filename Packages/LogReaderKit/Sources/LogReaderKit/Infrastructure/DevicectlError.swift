import Foundation

enum DevicectlError: Error {
    case toolMissing
    case timedOut
    case failed(status: Int32)
    case cacheNotReplaced(errno: Int32)
}
