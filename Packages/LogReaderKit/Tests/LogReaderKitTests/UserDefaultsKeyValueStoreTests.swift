import Foundation
import Testing
@testable import LogReaderKit

struct UserDefaultsKeyValueStoreTests {

    @Test func standardDefaultsIsTheStandardUserDefaults() {
        let store: any KeyValueStore = .standardDefaults

        #expect(store === UserDefaults.standard)
    }
}
