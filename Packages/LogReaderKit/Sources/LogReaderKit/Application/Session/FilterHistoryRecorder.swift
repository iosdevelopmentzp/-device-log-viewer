import Foundation
import LogReaderCore
import Observation

@MainActor
public final class FilterHistoryRecorder {

    private let session: LogSession
    private let settings: AppSettings
    private let delay: Duration
    private var isRunning = false
    private var observedFacets = FacetSelection.all
    private var observedBookmarksOnly = false
    private var recordTask: Task<Void, Never>?

    public init(session: LogSession, settings: AppSettings, delay: Duration) {
        self.session = session
        self.settings = settings
        self.delay = delay
    }

    public func start() {
        guard isRunning == false else { return }
        isRunning = true
        observedFacets = session.filterState.facets
        observedBookmarksOnly = session.filterState.bookmarksOnly
        observe()
    }

    public func stop() {
        isRunning = false
        recordTask?.cancel()
        recordTask = nil
    }
}

// MARK: - Private

private extension FilterHistoryRecorder {

    func observe() {
        guard isRunning else { return }
        withObservationTracking {
            _ = session.filterState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                filterStateDidChange()
                observe()
            }
        }
    }

    func filterStateDidChange() {
        guard isRunning else { return }
        let state = session.filterState
        guard state.facets != observedFacets || state.bookmarksOnly != observedBookmarksOnly else { return }
        observedFacets = state.facets
        observedBookmarksOnly = state.bookmarksOnly
        scheduleRecord()
    }

    func scheduleRecord() {
        recordTask?.cancel()
        recordTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: delay)
            guard Task.isCancelled == false else { return }
            record()
        }
    }

    func record() {
        let state = session.filterState
        guard state.facets.isAll == false || state.bookmarksOnly else { return }
        let entry = RecentFilterSet(
            id: UUID(),
            facets: state.facets,
            bookmarksOnly: state.bookmarksOnly,
            date: Date()
        )
        settings.filterHistory = settings.filterHistory.adding(entry)
    }
}
