//
//  MainScheduler.swift
//  CombineExtensions
//

import Combine
import Foundation

/// A scheduler that executes its work on the main queue as soon as possible.
///
/// If `MainScheduler.schedule` is invoked from the main thread then the unit of work may be
/// performed immediately.
///
/// This scheduler can be useful for situations where you need work executed as quickly as
/// possible on the main thread, and for which a thread hop would be problematic, such as when
/// updating UI.
///
/// - Important: The order between actions will always be preserved, except for recursive calls
/// which will be executed immediately and will not cause a thread hop.
public final class MainScheduler: @unchecked Sendable, Scheduler, Identifiable {
    public typealias SchedulerOptions = Never
    public typealias SchedulerTimeType = DispatchQueue.SchedulerTimeType

    /// The shared instance of the main scheduler.
    public static let shared = MainScheduler()

    /// Indicates whether this scheduler is performing the current action.
    public var isPerformingCurrentAction: Bool {
        return DispatchQueue.getSpecific(key: Constants.schedulerIdentifier) == id
    }

    public var now: SchedulerTimeType { DispatchQueue.main.now }
    public var minimumTolerance: SchedulerTimeType.Stride { DispatchQueue.main.minimumTolerance }

    private let lock: some Locking = Locks.default
    private var numberEnqueued: Int = 0

    public init() {}

    public func schedule(options _: SchedulerOptions? = nil, _ action: @escaping () -> Void) {
        let action = addSchedulerIdentifier(to: action)
        let previousNumberEnqueued = enqueueAction()

        if isPerformingCurrentAction || Thread.isMainThread && previousNumberEnqueued == 0 {
            action()
            dequeueAction()
        } else {
            DispatchQueue.main.async {
                action()
                self.dequeueAction()
            }
        }
    }

    public func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options _: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) {
        let action = addSchedulerIdentifier(to: action)
        DispatchQueue.main.schedule(after: date, tolerance: tolerance, options: nil, action)
    }

    public func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance: SchedulerTimeType.Stride,
        options _: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        let action = addSchedulerIdentifier(to: action)
        return DispatchQueue.main.schedule(after: date, interval: interval, tolerance: tolerance, options: nil, action)
    }

    @inline(__always)
    private func addSchedulerIdentifier(to action: @escaping () -> Void) -> () -> Void {
        let id = id
        return {
            DispatchQueue.main.setSpecific(key: Constants.schedulerIdentifier, value: id)
            action()
            DispatchQueue.main.setSpecific(key: Constants.schedulerIdentifier, value: nil)
        }
    }

    @discardableResult
    @inline(__always)
    private func enqueueAction() -> Int {
        return lock.withLock {
            let oldValue = numberEnqueued
            numberEnqueued += 1
            return oldValue
        }
    }

    @discardableResult
    @inline(__always)
    private func dequeueAction() -> Int {
        return lock.withLock {
            let oldValue = numberEnqueued
            numberEnqueued -= 1
            return oldValue
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let schedulerIdentifier = DispatchSpecificKey<ObjectIdentifier>()
}
