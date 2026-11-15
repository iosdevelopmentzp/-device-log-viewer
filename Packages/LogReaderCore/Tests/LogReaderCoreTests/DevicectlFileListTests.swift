import Foundation
import Testing
@testable import LogReaderCore

struct DevicectlFileListTests {

    private static let json = """
    {
      "result": {
        "domain": "appDataContainer",
        "domainIdentifier": "com.example.chat",
        "files": [
          {
            "relativePath": "Cache",
            "metadata": { "size": 96, "lastModDate": "2026-11-07T09:34:52.000Z" },
            "resources": { "isDirectory": true }
          },
          {
            "relativePath": "Cache/data.sqlite",
            "metadata": { "size": 4096, "lastModDate": "2026-11-07T09:34:52.000Z" },
            "resources": { "isDirectory": false }
          },
          {
            "relativePath": "Logs",
            "metadata": { "size": 96, "lastModDate": "2026-11-07T09:34:52.000Z" },
            "resources": { "isDirectory": true }
          },
          {
            "relativePath": "Logs/log-2026.11.06-08:00:00.txt",
            "metadata": { "size": 1200, "lastModDate": "2026-11-06T07:10:00.000Z" },
            "resources": { "isDirectory": false }
          },
          {
            "relativePath": "Logs/log-2026.11.07-10:34:52.txt",
            "metadata": { "size": 546960, "lastModDate": "2026-11-07T09:35:44.000Z" },
            "resources": { "isDirectory": false }
          },
          {
            "relativePath": "Logs/notes.json",
            "metadata": { "size": 10, "lastModDate": "2026-11-07T09:35:44.000Z" },
            "resources": { "isDirectory": false }
          },
          {
            "relativePath": "Logs/archive/log-2026.10.01-08:00:00.txt",
            "metadata": { "size": 10, "lastModDate": "2026-10-01T07:00:00.000Z" },
            "resources": { "isDirectory": false }
          },
          {
            "relativePath": "Logs/crash.txt",
            "metadata": { "size": 30, "lastModDate": "2026-11-05T12:00:00Z" },
            "resources": { "isDirectory": false }
          }
        ]
      }
    }
    """

    @Test func decodesEveryFile() throws {
        let list = try Self.decode()
        let file = try #require(list.files.first { $0.relativePath == "Logs/log-2026.11.07-10:34:52.txt" })

        #expect(list.files.count == 8)
        #expect(file.name == "log-2026.11.07-10:34:52.txt")
        #expect(file.size == 546960)
        #expect(file.isDirectory == false)
        #expect(file.lastModDate == Date(timeIntervalSince1970: 1_794_044_144))
    }

    private static let rule = DiscoveryRule(bundleIDPrefix: "com.example", logsPath: "Library/Application Support/Logs", fileExtension: "txt", fileNamePrefix: "")
    private static let prefixedRule = DiscoveryRule(bundleIDPrefix: "com.example", logsPath: "Library/Application Support/Logs", fileExtension: "txt", fileNamePrefix: "log-")

    @Test func keepsOnlyTextFilesDirectlyInLogsNewestFirst() throws {
        let list = try Self.decode()

        #expect(list.logFiles(rule: Self.rule).map(\.name) == ["log-2026.11.07-10:34:52.txt", "log-2026.11.06-08:00:00.txt", "crash.txt"])
        #expect(list.logFiles(rule: Self.prefixedRule).map(\.name) == ["log-2026.11.07-10:34:52.txt", "log-2026.11.06-08:00:00.txt"])
    }

    @Test func fileNameGivesTheCreationDateInLocalTime() throws {
        let list = try Self.decode()
        let file = try #require(list.logFiles(rule: Self.prefixedRule).first)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: file.createdAt(fileNamePrefix: "log-"))

        #expect(components == DateComponents(year: 2026, month: 11, day: 7, hour: 10, minute: 34, second: 52))
    }

    @Test func lastModificationDateIsTheFallback() throws {
        let list = try Self.decode()
        let file = try #require(list.logFiles(rule: Self.rule).first { $0.name == "crash.txt" })

        #expect(file.createdAt(fileNamePrefix: "log-") == Date(timeIntervalSince1970: 1_793_880_000))
        #expect(file.createdAt(fileNamePrefix: "") == Date(timeIntervalSince1970: 1_793_880_000))
    }

    @Test func folderHelpersSplitTheLogsPath() {
        #expect(DevicectlFileList.lastFolder(of: "Library/Application Support/Logs") == "Logs")
        #expect(DevicectlFileList.parentFolder(of: "Library/Application Support/Logs") == "Library/Application Support")
        #expect(DevicectlFileList.parentFolder(of: "Logs") == "")
    }

    private static func decode() throws -> DevicectlFileList {
        try JSONDecoder().decode(DevicectlFileList.self, from: Data(json.utf8))
    }
}
