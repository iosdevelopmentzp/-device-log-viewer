import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct DisplayExtensionsTests {

    @Test func appearanceNamesAndSymbols() {
        #expect(Appearance.allCases.map(\.displayName) == ["System", "Light", "Dark"])
        #expect(Appearance.allCases.map(\.symbolName) == ["circle.lefthalf.filled", "sun.max", "moon"])
    }

    @Test func exportFormatNamesAndExtensions() {
        #expect(ExportFormat.allCases.map(\.displayName) == ["Log file", "JSON"])
        #expect(ExportFormat.allCases.map(\.fileExtension) == ["txt", "json"])
    }

    @Test func updatePhaseNames() {
        #expect(UpdatePhase.allCases.map(\.displayName) == ["Getting changes", "Building", "Installing", "Done", "Failed"])
    }

    @Test func timeZoneModeNames() {
        #expect(TimeZoneMode.allCases.map(\.displayName) == ["Local", "UTC"])
    }

    @Test func searchModeNamesAndPrompts() {
        #expect(SearchMode.allCases.map(\.displayName) == ["Filter", "Find"])
        #expect(SearchMode.allCases.map(\.prompt) == ["Filter entries (⌘F)", "Find in entries (⌘F)"])
    }

    @Test func searchScopeNames() {
        let profile = ProfileFixtures.textTrailing
        let names = SearchScope.optionIDs(in: profile).map { SearchScope.displayName(ofID: $0, in: profile) }

        #expect(names == ["Message and fields", "Tags", "Category", "Source", "Level"])
        #expect(SearchScope.displayName(ofID: "unknown", in: profile) == "unknown")
    }

    @Test func searchScopeSummaryFollowsTheProfileOrder() {
        let scope = SearchScope(ids: ["level", "source", "message"])

        #expect(scope.summary(in: ProfileFixtures.textTrailing) == "Message and fields, Source, Level")
    }

    @Test func searchScopeSummaryOfTheBuiltInProfile() {
        let scope = SearchScope(ids: ["subsystem", "message"])

        #expect(scope.summary(in: ProfileFixtures.jsonLines) == "Message and fields, Subsystem")
    }

    @Test func facetModeNames() {
        #expect(FacetMode.allCases.map(\.displayName) == ["Show only checked", "Hide checked"])
    }

    @Test func facetColumnNames() {
        let profile = ProfileFixtures.textTrailing
        let columns = FacetColumn.all(in: profile)

        #expect(columns.map { $0.displayName(in: profile) } == ["Level", "Tags", "Category", "Source"])
        #expect(columns.map { $0.columnTitle(in: profile) } == ["Level", "Tags", "Category", "Source"])
        #expect(columns.map { $0.valuePrefix(in: profile) } == ["", "#", "", ""])
        #expect(FacetColumn.attribute("unknown").displayName(in: profile) == "unknown")
    }

    @Test func logTableColumnNames() {
        let profile = ProfileFixtures.textTrailing

        #expect(LogTableColumn.all(in: profile).map { $0.displayName(in: profile) } == ["#", "Time", "Δ", "Level", "Tags", "Category", "Source", "Message"])
        #expect(LogTableColumn.attribute("unknown").displayName(in: profile) == "unknown")
    }

    @Test func sourceRuleNamesTheEditor() {
        let other = SourceRule(fileExtension: "kt", editorCommand: "/usr/local/bin/idea", editorArguments: ["{path}"])

        #expect(SourceRule.standard.editorDisplayName == "Xcode")
        #expect(SourceRule.standard.openTitle == "Open in Xcode")
        #expect(other.openTitle == "Open in Editor")
    }

    @Test func rowDensityNames() {
        #expect(RowDensity.allCases.map(\.displayName) == ["Compact", "Comfortable"])
    }

    @Test func fontFamilyNames() {
        #expect(FontFamily.allCases.map(\.displayName) == ["Monospaced", "System"])
    }

    @Test func deviceTransportNames() {
        #expect([DeviceTransport.usb, .network, .unknown].map(\.displayName) == ["USB", "Wi-Fi", ""])
    }
}
