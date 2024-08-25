//
//  DiscardableSubscribeOnTests.swift
//  CombineExtensionsTests
//

import Combine
@testable import CombineExtensions
import XCTest

final class DiscardableSubscribeOnTests: XCTestCase {
    private let subject = PassthroughSubject<Int, SomeError>()

    private var subscription: Subscription!
    private var cancellable: ThreadSafeCancellable!

    private var values = [Int]()
    private var completions = [Subscribers.Completion<SomeError>]()

    private let scheduler = TestScheduler()

    func testSubscription() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        XCTAssertNotNil(subscription, "Subscription object should be sent synchronously")

        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(scheduler.schedulingCount, 0)
        XCTAssertEqual(scheduler.scheduledCount, 1)
    }

    func testSubscriptionSchedulerCalls() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        subscription.request(.unlimited)
        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(scheduler.schedulingCount, 0)
        XCTAssertEqual(scheduler.scheduledCount, 1)
    }

    func testSubscriptionSchedulerCalls2() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        scheduler.waitUntilAllScheduled()

        subscription.request(.unlimited)
        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(scheduler.schedulingCount, 0)
        XCTAssertEqual(scheduler.scheduledCount, 2)
    }

    func testSynchronouslySendsEventsDownstream() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        subscription.request(.unlimited)

        scheduler.waitUntilAllScheduled()

        [1, 2, 3].forEach(subject.send)

        XCTAssertEqual(values, [1, 2, 3])
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(scheduler.scheduledCount, 1)

        subject.send(completion: .finished)
        scheduler.waitUntilAllScheduled()

        XCTAssertEqual(values, [1, 2, 3])
        XCTAssertEqual(completions, [.finished])
        XCTAssertEqual(scheduler.scheduledCount, 1)
    }

    func testSynchronouslySendsEventsDownstream2() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        subscription.request(.unlimited)
        scheduler.waitUntilAllScheduled()

        [1, 2, 3].forEach(subject.send)

        XCTAssertEqual(values, [1, 2, 3])
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(scheduler.scheduledCount, 1)

        subject.send(completion: .failure(SomeError()))

        XCTAssertEqual(values, [1, 2, 3])
        XCTAssertEqual(completions, [.failure(SomeError())])
        XCTAssertEqual(scheduler.scheduledCount, 1)
    }

    func testAsynchronouslySendsEventsUpstream() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        scheduler.waitUntilAllScheduled()
        XCTAssertEqual(scheduler.scheduledCount, 1)

        subscription.request(.max(17))
        subscription.request(.unlimited)
        subscription.request(.none)

        scheduler.waitUntilAllScheduled()
        XCTAssertEqual(scheduler.scheduledCount, 4)

        subscription.cancel()
        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertTrue(cancellable.checkCancellation())
        XCTAssertEqual(scheduler.scheduledCount, 5)
    }

    func testCancelAlreadyCancelled() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        scheduler.waitUntilAllScheduled()

        subscription.cancel()

        subject.send(1)
        subject.send(completion: .failure(SomeError()))

        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(cancellable.checkCancellation())
        XCTAssertEqual(scheduler.scheduledCount, 2)

        subscription.request(.max(1))
        subscription.cancel()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertTrue(cancellable.checkCancellation())
        XCTAssertEqual(scheduler.scheduledCount, 2)
    }

    func testCancelImmediatelyAfterRequest() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        scheduler.waitUntilAllScheduled()

        subscription.request(.max(1))
        subscription.cancel()

        scheduler.waitUntilAllScheduled()

        XCTAssertEqual(scheduler.scheduledCount, 3)

        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertTrue(cancellable.checkCancellation())
        XCTAssertEqual(scheduler.scheduledCount, 3)
    }

    func testCancelImmediatelyBeforeSubscribe() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber())

        subscription.cancel()

        scheduler.waitUntilAllScheduled()

        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertTrue(cancellable.checkCancellation())
        XCTAssertEqual(scheduler.scheduledCount, 1)
    }

    func testRequestImmediatelyBeforeSubscribe() {
        subject
            .discardableSubscribe(on: scheduler)
            .subscribe(makeSubscriber { .none })

        subscription.request(.max(3))

        scheduler.waitUntilAllScheduled()

        [0, 1, 2, 3].forEach(subject.send)

        XCTAssertEqual(values, [0, 1, 2])
        XCTAssertTrue(completions.isEmpty)
        XCTAssertFalse(cancellable.checkCancellation())
        XCTAssertEqual(scheduler.scheduledCount, 1)
    }
}

// MARK: - Test Default Implementation

extension DiscardableSubscribeOnTests {
    func testSubscribeOn() {
        let subscription = subject
            .subscribe(on: scheduler)
            .sink { [unowned self] in
                completions.append($0)
            } receiveValue: { [unowned self] in
                values.append($0)
            }

        subscription.cancel()

        scheduler.waitUntilAllScheduled()

        [0, 1, 2].forEach(subject.send)

        /// Should be empty.
        XCTAssertEqual(values, [0, 1, 2])
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(scheduler.schedulingCount, 0)
        /// This can be optimized to a single schedule call.
        XCTAssertEqual(scheduler.scheduledCount, 2)
    }
}

// MARK: - Helpers

private extension DiscardableSubscribeOnTests {
    private func makeSubscriber(demand: @escaping () -> Subscribers.Demand = { .unlimited }) -> AnySubscriber<Int, SomeError> {
        return AnySubscriber { [unowned self] in
            subscription = $0
            cancellable = $0 as? ThreadSafeCancellable

        } receiveValue: { [unowned self] in
            values.append($0)
            return demand()

        } receiveCompletion: { [unowned self] in
            completions.append($0)
        }
    }
}

private final class TestScheduler: Scheduler {
    typealias SchedulerTimeType = DispatchQueue.SchedulerTimeType
    typealias SchedulerOptions = DispatchQueue.SchedulerOptions

    var now: DispatchQueue.SchedulerTimeType { queue.now }
    var minimumTolerance: DispatchQueue.SchedulerTimeType.Stride { queue.minimumTolerance }

    var schedulingCount: Int { lock.withLock { _schedulingCount } }
    var scheduledCount: Int { lock.withLock { _scheduledCount } }

    private let lock = NSRecursiveLock()
    private let queue = DispatchQueue(label: "TestSchedulerQueue")

    private var isPaused = true
    private var pausedActions = [(options: DispatchQueue.SchedulerOptions?, action: () -> Void)]()

    private var _schedulingCount = 0
    private var _scheduledCount = 0

    func pause() {
        lock.withLock { isPaused = true }
    }

    func resume() {
        lock.withLock {
            isPaused = false
            pausedActions.forEach { schedule(options: $0.options, $0.action) }
            pausedActions.removeAll()
        }
    }

    func waitUntilAllScheduled() {
        resume()
        while schedulingCount > 0 { queue.sync {} }
    }

    func schedule(options: DispatchQueue.SchedulerOptions?, _ action: @escaping () -> Void) {
        if lock.withLock({ isPaused }) {
            lock.withLock { pausedActions.append((options, action)) }
            return
        }

        lock.withLock { _schedulingCount += 1 }

        queue.schedule(options: options) { [weak self] in
            guard let self else { return }

            action()
            lock.withLock {
                self._schedulingCount -= 1
                self._scheduledCount += 1
            }
        }
    }

    func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        lock.withLock { _schedulingCount += 1 }

        queue.schedule(after: date, tolerance: tolerance, options: options) { [weak self] in
            guard let self else { return }

            action()
            lock.withLock {
                self._schedulingCount -= 1
                self._scheduledCount += 1
            }
        }
    }

    func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        lock.withLock { _schedulingCount += 1 }

        return queue.schedule(after: date, interval: interval, tolerance: tolerance, options: options) { [weak self] in
            guard let self else { return }

            action()
            lock.withLock {
                self._schedulingCount -= 1
                self._scheduledCount += 1
            }
        }
    }
}

private struct SomeError: Error, Equatable {}
