import Foundation

enum ByteScan {

    static func index(of byte: UInt8, in bytes: UnsafeRawBufferPointer, from start: Int, to end: Int) -> Int? {
        guard start < end, let base = bytes.baseAddress else { return nil }
        guard let found = memchr(base + start, Int32(byte), end - start) else { return nil }
        return base.distance(to: UnsafeRawPointer(found))
    }
}
