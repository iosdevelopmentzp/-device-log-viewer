import Foundation

@MainActor
public final class LogFilterRunner {

    private let debounce: Duration
    private var task: Task<FilterResult?, Never>?
    private var generation = 0

    public init(debounce: Duration) {
        self.debounce = debounce
    }

    public func run(_ request: FilterRequest, debounced: Bool) async -> FilterResult? {
        cancel()
        let current = generation
        let delay = debounced ? debounce : nil
        let newTask = Task { await Self.compute(request, delay: delay) }
        task = newTask
        let result = await withTaskCancellationHandler {
            await newTask.value
        } onCancel: {
            newTask.cancel()
        }
        guard current == generation else { return nil }
        task = nil
        return result
    }

    public func cancel() {
        task?.cancel()
        task = nil
        generation += 1
    }
}

// MARK: - Private

private extension LogFilterRunner {

    nonisolated static func compute(_ request: FilterRequest, delay: Duration?) async -> FilterResult? {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        guard Task.isCancelled == false else { return nil }
        let work = Task.detached(priority: .userInitiated) {
            try? FilterResult.compute(request)
        }
        let result = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        guard Task.isCancelled == false else { return nil }
        return result
    }
}
