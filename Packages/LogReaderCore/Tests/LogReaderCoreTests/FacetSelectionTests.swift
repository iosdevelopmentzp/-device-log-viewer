import Foundation
import Testing
@testable import LogReaderCore

struct FacetSelectionTests {

    private let tags = FacetColumn.attribute("tags")
    private let category = FacetColumn.attribute("category")
    private let source = FacetColumn.attribute("source")

    @Test func allIsInactive() {
        let selection = FacetSelection.all
        #expect(selection.isAll)
        for column in [FacetColumn.level, tags, category, source] {
            #expect(selection.isActive(column) == false)
            #expect(selection.isSelected("x", in: column) == false)
        }
        #expect(selection.activeColumns.isEmpty)
    }

    @Test func toggleLevelUsesIDs() {
        var selection = FacetSelection.all
        selection.toggle("error", in: .level)

        #expect(selection.levels == .only(["error"]))
        #expect(selection.isActive(.level))
        #expect(selection.isSelected("error", in: .level))
        #expect(selection.isSelected("warning", in: .level) == false)
        #expect(selection.isAll == false)
        #expect(selection.activeColumns == [.level])

        selection.toggle("error", in: .level)
        #expect(selection.levels == .all)
        #expect(selection.isAll)
    }

    @Test func toggleAttributeColumnsUseOwnFilter() {
        var selection = FacetSelection.all
        selection.toggle("network", in: tags)
        selection.toggle("default", in: category)
        selection.toggle("Store", in: source)

        #expect(selection[tags] == .only(["network"]))
        #expect(selection[category] == .only(["default"]))
        #expect(selection[source] == .only(["Store"]))
        #expect(selection.levels == .all)
        #expect(selection.activeColumns == [category, source, tags])
    }

    @Test func showOnlyReplacesSelection() {
        var selection = FacetSelection.all
        selection.toggle("a", in: tags)
        selection.showOnly(["b", "c"], in: tags)
        #expect(selection[tags] == .only(["b", "c"]))

        selection.showOnly([], in: tags)
        #expect(selection[tags] == .all)
    }

    @Test func showAllResetsOneColumn() {
        var selection = FacetSelection.all
        selection.toggle("a", in: tags)
        selection.toggle("debug", in: .level)
        selection.showAll(in: tags)

        #expect(selection[tags] == .all)
        #expect(selection.levels == .only(["debug"]))
    }

    @Test func excludeReplacesTheColumnFilter() {
        var selection = FacetSelection.all
        selection.toggle("a", in: tags)
        selection.exclude(["b"], in: tags)
        #expect(selection[tags] == .except(["b"]))
        #expect(selection.isExcluding(tags))
        #expect(selection.mode(of: tags) == .exclude)
        #expect(selection.isSelected("b", in: tags))

        selection.exclude([], in: tags)
        #expect(selection[tags] == .all)
        #expect(selection.mode(of: tags) == .include)
    }

    @Test func addExcludedAddsToExceptAndReplacesOnly() {
        var selection = FacetSelection.all
        selection.showOnly(["a"], in: category)
        selection.addExcluded(["b"], in: category)
        #expect(selection[category] == .except(["b"]))

        selection.addExcluded(["c"], in: category)
        #expect(selection[category] == .except(["b", "c"]))
    }

    @Test func toggleUnderExceptKeepsTheMode() {
        var selection = FacetSelection.all
        selection.exclude(["a"], in: source)
        selection.toggle("b", in: source)
        #expect(selection[source] == .except(["a", "b"]))

        selection.toggle("a", in: source)
        selection.toggle("b", in: source)
        #expect(selection[source] == .all)
    }

    @Test func setModeConvertsTheSet() {
        var selection = FacetSelection.all
        selection.setMode(.exclude, in: tags)
        #expect(selection[tags] == .all)

        selection.showOnly(["a", "b"], in: tags)
        selection.setMode(.exclude, in: tags)
        #expect(selection[tags] == .except(["a", "b"]))

        selection.setMode(.include, in: tags)
        #expect(selection[tags] == .only(["a", "b"]))
    }

    @Test func codableRoundTrip() throws {
        let selection = FacetSelection(filters: [
            .level: .except(["debug"]),
            tags: .only(["network", "auth"]),
            category: .all,
            source: .except(["Store"])
        ])

        let data = try JSONEncoder().encode(selection)
        let decoded = try JSONDecoder().decode(FacetSelection.self, from: data)

        #expect(decoded == selection)
        #expect(decoded.activeColumns == [.level, source, tags])
        #expect(try JSONDecoder().decode(FacetSelection.self, from: JSONEncoder().encode(FacetSelection.all)) == .all)
    }

    @Test func decodesTheOldEncoding() throws {
        let json = """
        {"levels":{"except":{"_0":[0,4]}},"columns":{"tags":{"only":{"_0":["network"]}},"source":{"all":{}}}}
        """
        let decoded = try JSONDecoder().decode(FacetSelection.self, from: Data(json.utf8))

        #expect(decoded.levels == .except(["debug", "error"]))
        #expect(decoded[tags] == .only(["network"]))
        #expect(decoded[source] == .all)
    }
}
