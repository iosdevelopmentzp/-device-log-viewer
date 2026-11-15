import Foundation
import Testing
@testable import LogReaderKit

struct FileSizeTextTests {

    @Test func usesTheByteCountFormatterStyles() {
        #expect(FileSizeText.file(2_048) == ByteCountFormatter.string(fromByteCount: 2_048, countStyle: .file))
        #expect(FileSizeText.memory(2_048) == ByteCountFormatter.string(fromByteCount: 2_048, countStyle: .memory))
        #expect(FileSizeText.file(0) == ByteCountFormatter.string(fromByteCount: 0, countStyle: .file))
    }
}
