import Foundation
import LogReaderCore

@MainActor
public final class ErrorAlertController {

    public private(set) var pendingErrorCount = 0

    private let settings: AppSettings
    private let attention: any AppAttention
    private weak var session: LogSession?
    private var hasRequestedAttention = false
    private var isInitialLoadPending = false

    public init(settings: AppSettings, attention: any AppAttention) {
        self.settings = settings
        self.attention = attention
    }

    public func start() {
        attention.observer = self
    }

    public func stop() {
        detach()
        attention.observer = nil
        clearPending()
    }

    public func attach(to session: LogSession) {
        detach()
        session.appendObserver = self
        self.session = session
        isInitialLoadPending = true
    }

    public func detach() {
        session?.appendObserver = nil
        session = nil
    }
}

// MARK: - LogAppendObserver

extension ErrorAlertController: LogAppendObserver {

    public func session(_ session: LogSession, didAppend range: Range<Int>) {
        guard isInitialLoadPending == false else {
            isInitialLoadPending = false
            return
        }
        guard settings.alertsOnErrors, attention.isAppActive == false else { return }
        let alertLevels = Set(session.profile.alertLevels)
        let count = session.content.records[range].count { $0.level.map(alertLevels.contains) ?? false }
        guard count > 0 else { return }
        pendingErrorCount += count
        if hasRequestedAttention == false {
            attention.requestAttention()
            hasRequestedAttention = true
        }
        attention.setBadge(String(pendingErrorCount))
    }
}

// MARK: - AppAttentionObserver

extension ErrorAlertController: AppAttentionObserver {

    public func appDidBecomeActive() {
        clearPending()
    }
}

// MARK: - Private

private extension ErrorAlertController {

    func clearPending() {
        pendingErrorCount = 0
        hasRequestedAttention = false
        attention.setBadge(nil)
    }
}
