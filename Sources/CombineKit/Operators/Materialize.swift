//
//  Materialize.swift
//  CombineKit
//
//  Created by Shai Mishali on 14/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import Combine

public extension Publisher {
    /// Converts any publisher to a publisher of its events.
    ///
    /// - note: The returned publisher is guaranteed to never fail,
    ///         but it will complete given any upstream completion event.
    ///
    /// - returns: A publisher that wraps events in an `Event<Output, Failure>`.
    func materialize() -> Publishers.Materialize<Self> {
        return Publishers.Materialize(upstream: self)
    }
}

// MARK: - Materialized Operators

public extension Publisher where Output: EventConvertible, Failure == Never {
    /// Given a materialized publisher, publish only the emitted
    /// upstream values, omitting failures.
    ///
    /// - returns: A publisher emitting the `Output` of the wrapped event.
    func values() -> AnyPublisher<Output.Output, Never> {
        compactMap {
            guard case let .value(value) = $0.event else { return nil }
            return value
        }
        .eraseToAnyPublisher()
    }

    /// Given a materialize publisher, publish only the emitted
    /// upstream failure, if exists, omitting values.
    ///
    /// - returns: A publisher emitting the `Failure` of the wrapped event.
    func failures() -> AnyPublisher<Output.Failure, Never> {
        compactMap {
            guard case let .failure(error) = $0.event else { return nil }
            return error
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Publisher

public extension Publishers {
    /// A publisher which takes an upstream publisher and emits its events,
    /// wrapped in `Event<Output, Failure>`.
    ///
    /// - note: This publisher is guaranteed to never fail, but it
    ///         will complete given any upstream completion event.
    struct Materialize<Upstream: Publisher>: Publisher {
        public typealias Output = Event<Upstream.Output, Upstream.Failure>
        public typealias Failure = Never

        private let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Subscription(upstream: upstream, downstream: subscriber))
        }
    }
}

// MARK: - Subscription

private extension Publishers.Materialize {
    final class Subscription<Downstream: Subscriber>: ThreadSafeCancellable, Combine.Subscription
    where
        Downstream.Input == Event<Upstream.Output, Upstream.Failure>,
        Downstream.Failure == Never
    {
        private var sink: Sink<Downstream>?

        init(
            upstream: Upstream,
            downstream: Downstream
        ) {
            self.sink = Sink(
                upstream: upstream,
                downstream: downstream,
                transformOutput: { .value($0) }
            )
            upstream.subscribe(sink!)
        }

        deinit { cancel() }

        func request(_ demand: Subscribers.Demand) {
            let sink = withCancellationLock { self.sink }
            sink?.demand(demand)
        }

        override func cancel() {
            withCheckedCancellation {
                sink.kill()
            }
        }
    }
}

// MARK: - Sink

private extension Publishers.Materialize {
    final class Sink<Downstream: Subscriber>: CombineKit.Sink<Upstream, Downstream>
    where
        Downstream.Input == Event<Upstream.Output, Upstream.Failure>,
        Downstream.Failure == Never
    {
        override func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            // We're overriding the standard completion buffering mechanism
            // to buffer these events as regular materialized values, and send
            // a regular finished event in either case.
            switch completion {
            case .finished:
                _ = buffer.buffer(value: .finished)
            case let .failure(error):
                _ = buffer.buffer(value: .failure(error))
            }

            buffer.complete(completion: .finished)
            cancel()
        }
    }
}

extension Publishers.Materialize.Subscription: CustomStringConvertible {
    var description: String {
        return "Materialize.Subscription<\(Downstream.Input.Output.self), \(Downstream.Input.Failure.self)>"
    }
}
