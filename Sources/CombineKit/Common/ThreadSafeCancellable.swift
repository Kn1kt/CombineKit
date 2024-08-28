//
//  ThreadSafeCancellable.swift
//  CombineKit
//

import Combine

/// A thread-safe Cancellable that run ``Combine/Cancellable/cancel()`` only once.
/// Any subsequent calls doesn't anything.
class ThreadSafeCancellable: Cancellable {
    private let lock: some Locking = Locks.default
    private var isCancelled = false

    init() {}

    /// Cancel the activity.
    ///
    /// When overriding this method,
    /// you must call ``ThreadSafeCancellable/withCheckedCancellation(:)`` at start point in your implementation.
    ///
    /// > Tip: Keep in mind that your `cancel()` may execute concurrently with another call to `cancel()`
    /// --- including the scenario where an ``Combine/AnyCancellable`` is deallocating ---
    /// or to ``Combine/Subscription/request(_:)``.
    func cancel() {}

    /// Check if the activity was canceled.
    /// - Returns: A Boolean value that indicates whether the activity was canceled.
    final func checkCancellation() -> Bool {
        return withCancellationLock {} == nil
    }

    /// Ensures that the cancellation will occur only once.
    /// - Parameter cancel: A closure that cancel activity.
    final func withCheckedCancellation(_ cancel: @Sendable () -> Void) {
        let needToCancel = lock.withLock {
            if isCancelled { return false }
            isCancelled = true
            return true
        }

        if needToCancel { cancel() }
    }

    /// Perform a sendable closure if `self` not cancelled.
    ///
    /// All values released in ``ThreadSafeCancellable/cancel()`` must be obtained through this lock to avoid data races.
    ///
    /// - Parameter body: A sendable closure to invoke.
    /// - Returns: The return value of `body` or `nil` if `self` already cancelled.
    /// - Throws: Anything thrown by `body`.
    final func withCancellationLock<R: Sendable>(_ body: @Sendable () throws -> R?) rethrows -> R? {
        return try lock.withLock {
            if isCancelled { return nil }
            return try body()
        }
    }
}
