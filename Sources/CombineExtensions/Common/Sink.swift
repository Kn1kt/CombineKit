//
//  Sink.swift
//  CombineExtensions
//
//  Created by Shai Mishali on 14/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import Combine

/// A generic sink using an underlying demand buffer to balance
/// the demand of a downstream subscriber for the events of an
/// upstream publisher.
class Sink<Upstream: Publisher, Downstream: Subscriber>: ThreadSafeCancellable, Subscriber {
    typealias TransformFailure = (Upstream.Failure) -> Downstream.Failure?
    typealias TransformOutput = (Upstream.Output) -> Downstream.Input?

    let buffer: DemandBuffer<Downstream>

    private let transformOutput: TransformOutput?
    private let transformFailure: TransformFailure?

    private let upstreamLock: some Locking = Locks.recursive
    private var upstreamSubscription: Subscription?

    /// Initialize a new sink subscribing to the upstream publisher and
    /// fulfilling the demand of the downstream subscriber using a backpressure
    /// demand-maintaining buffer.
    ///
    /// - parameter upstream: The upstream publisher.
    /// - parameter downstream: The downstream subscriber.
    /// - parameter transformOutput: Transform the upstream publisher's output type to the downstream's input type.
    /// - parameter transformFailure: Transform the upstream failure type to the downstream's failure type.
    ///
    /// - note: You **must** provide the two transformation functions above if you're using
    ///         the default `Sink` implementation. Otherwise, you must subclass `Sink` with your own
    ///         publisher's sink and manage the buffer accordingly.
    init(
        upstream _: Upstream,
        downstream: Downstream,
        transformOutput: TransformOutput? = nil,
        transformFailure: TransformFailure? = nil
    ) {
        self.buffer = DemandBuffer(subscriber: downstream)
        self.transformOutput = transformOutput
        self.transformFailure = transformFailure
    }

    convenience init(forwardingFrom upstream: Upstream, to downstream: Downstream)
    where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
        self.init(upstream: upstream, downstream: downstream, transformOutput: { $0 }, transformFailure: { $0 })
    }

    deinit { cancel() }

    final func demand(_ demand: Subscribers.Demand) {
        let newDemand = buffer.demand(demand)

        let upstreamSubscription = withCancellationLock { self.upstreamSubscription }

        if let upstreamSubscription {
            upstreamLock.withLock {
                upstreamSubscription.requestIfNeeded(newDemand)
            }
        }
    }

    final func receive(subscription: Subscription) {
        let previousUpstreamSubscription = withCancellationLock {
            defer { upstreamSubscription = subscription }
            return upstreamSubscription
        }
        previousUpstreamSubscription?.cancel()

        let newDemand = buffer.attachToNewUpstream()
        upstreamLock.withLock {
            subscription.requestIfNeeded(newDemand)
        }
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        guard let transform = transformOutput else {
            fatalError("""
                ❌ Missing output transformation
                =========================

                You must either:
                    - Provide a transformation function from the upstream's output to the downstream's input; or
                    - Subclass `Sink` with your own publisher's Sink and manage the buffer yourself
            """)
        }

        guard let input = transform(input) else { return .none }
        return buffer.buffer(value: input)
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        switch completion {
        case .finished:
            buffer.complete(completion: .finished)
        case let .failure(error):
            guard let transform = transformFailure else {
                fatalError("""
                    ❌ Missing failure transformation
                    =========================

                    You must either:
                        - Provide a transformation function from the upstream's failure to the downstream's failuer; or
                        - Subclass `Sink` with your own publisher's Sink and manage the buffer yourself
                """)
            }

            guard let error = transform(error) else { return }
            buffer.complete(completion: .failure(error))
        }

        cancel()
    }

    override final func cancel() {
        withCheckedCancellation {
            upstreamSubscription.kill()
        }
    }
}
