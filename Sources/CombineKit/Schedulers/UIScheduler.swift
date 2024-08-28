//
//  UIScheduler.swift
//  CombineKit
//

import Combine
import Foundation

/// A scheduler that executes its work on the main queue as soon as possible.
///
/// If `UIScheduler.schedule` is invoked from the main thread then the unit of work will be
/// performed immediately. This is in contrast to `MainScheduler.schedule`, which can incur
/// a thread hop before executing, since it guarantees event ordering.
///
/// This scheduler can be useful for situations where you need work executed as quickly as
/// possible on the main thread, and for which a thread hop would be problematic, such as when
/// performing animations.
///
/// - Important: The order between actions may not be preserved, if this is matter,
/// use `MainScheduler` instead.
public struct UIScheduler: Scheduler, Sendable {
    public typealias SchedulerOptions = Never
    public typealias SchedulerTimeType = DispatchQueue.SchedulerTimeType

    /// The shared instance of the UI scheduler.
    ///
    /// You cannot create instances of the UI scheduler yourself. Use only the shared instance.
    public static let shared = Self()

    public var now: SchedulerTimeType { DispatchQueue.main.now }
    public var minimumTolerance: SchedulerTimeType.Stride { DispatchQueue.main.minimumTolerance }

    private init() {}

    public func schedule(options _: SchedulerOptions? = nil, _ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.schedule(action)
        }
    }

    public func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options _: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) {
        DispatchQueue.main.schedule(after: date, tolerance: tolerance, options: nil, action)
    }

    public func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance: SchedulerTimeType.Stride,
        options _: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        return DispatchQueue.main.schedule(after: date, interval: interval, tolerance: tolerance, options: nil, action)
    }
}
