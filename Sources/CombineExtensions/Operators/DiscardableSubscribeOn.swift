//
//  DiscardableSubscribeOn.swift
//  CombineExtensions
//

import Combine

// MARK: - Operator methods

public extension Publisher {
    /// An efficient version of `subscribe(on:options:)` with optimized `cancel()` and `request(_:)`.
    ///
    /// In contrast with `receive(on:options:)`, which affects downstream messages,
    /// `subscribe(on:options:)` changes the execution context of upstream messages.
    ///
    /// In the following example, the `subscribe(on:options:)` operator causes
    /// `ioPerformingPublisher` to receive requests on `backgroundQueue`, while
    /// the `receive(on:options:)` causes `uiUpdatingSubscriber` to receive elements and
    /// completion on `RunLoop.main`.
    ///
    ///     let ioPerformingPublisher == // Some publisher.
    ///     let uiUpdatingSubscriber == // Some subscriber that updates the UI.
    ///
    ///     ioPerformingPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receive(on: RunLoop.main)
    ///         .subscribe(uiUpdatingSubscriber)
    ///
    ///
    /// Using `subscribe(on:options:)` also causes the upstream publisher to perform
    /// `cancel()` using the specified scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler used to send messages to upstream publishers.
    ///   - options: Options that customize the delivery of elements.
    /// - Returns: A publisher which performs upstream operations on the specified
    ///   scheduler.
    func discardableSubscribe<Context: Scheduler>(
        on scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.DiscardableSubscribeOn<Self, Context> {
        return .init(upstream: self, scheduler: scheduler, options: options)
    }
}

// MARK: - Publisher

public extension Publishers {
    /// A publisher that receives elements from an upstream publisher on a specific
    /// scheduler.
    struct DiscardableSubscribeOn<Upstream: Publisher, Context: Scheduler>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The scheduler the publisher should use to receive elements.
        public let scheduler: Context

        /// Scheduler options that customize the delivery of elements.
        public let options: Context.SchedulerOptions?

        public init(upstream: Upstream, scheduler: Context, options: Context.SchedulerOptions?) {
            self.upstream = upstream
            self.scheduler = scheduler
            self.options = options
        }

        public func receive<S: Subscriber>(subscriber: S) where Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            subscriber.receive(
                subscription: Subscription(
                    upstream: upstream,
                    downstream: subscriber,
                    scheduler: scheduler,
                    options: options
                )
            )
        }
    }
}

// MARK: - Subscription

private extension Publishers.DiscardableSubscribeOn {
    final class Subscription<Downstream: Subscriber>: ThreadSafeCancellable, Combine.Subscription
    where
        Downstream.Input == Upstream.Output,
        Downstream.Failure == Upstream.Failure
    {
        private let upstream: Upstream
        private let downstream: Downstream

        private let scheduler: Context
        private let options: Context.SchedulerOptions?

        private var preInitialDemand = Subscribers.Demand.none
        private var sink: Sink<Upstream, Downstream>?

        init(
            upstream: Upstream,
            downstream: Downstream,
            scheduler: Context,
            options: Context.SchedulerOptions?
        ) {
            self.upstream = upstream
            self.downstream = downstream
            self.scheduler = scheduler
            self.options = options

            super.init()

            scheduler.schedule(options: options) { [weak self] in
                guard let self else { return }

                let sink = Sink(forwardingFrom: upstream, to: downstream)

                let preInitialDemand = withCancellationLock {
                    self.sink = sink
                    defer { self.preInitialDemand = .none }
                    return self.preInitialDemand
                }

                if let preInitialDemand {
                    upstream.subscribe(sink)
                    sink.demand(preInitialDemand)
                }
            }
        }

        deinit { cancel() }

        func request(_ demand: Subscribers.Demand) {
            let needToRequestDemand = withCancellationLock {
                guard sink == nil else { return true }

                preInitialDemand += demand

                return false
            }

            guard needToRequestDemand == true else { return }

            scheduler.schedule(options: options) { [weak self] in
                guard let self else { return }

                let sink = withCancellationLock { self.sink }
                sink?.demand(demand)
            }
        }

        override func cancel() {
            withCheckedCancellation {
                guard let sink else { return }

                scheduler.schedule(options: options) { sink.cancel() }
                self.sink = nil
            }
        }
    }
}

extension Publishers.DiscardableSubscribeOn.Subscription: CustomStringConvertible {
    var description: String {
        return "DiscardableSubscribeOn.Subscription<\(Upstream.Output.self), \(Upstream.Failure.self)>"
    }
}
