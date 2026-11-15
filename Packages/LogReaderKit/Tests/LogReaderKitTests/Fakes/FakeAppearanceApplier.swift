import LogReaderKit

@MainActor
final class FakeAppearanceApplier: AppearanceApplier {

    private(set) var appliedAppearances: [Appearance] = []

    func apply(_ appearance: Appearance) {
        appliedAppearances.append(appearance)
    }
}
