//
//  PrefixWhile.swift
//  CombineKit
//

import Combine

public extension Publisher {
    /// An overload on `Publisher.prefix(while:)` that allows for inclusion of the first element that doesn’t pass the `while`
    /// predicate.
    ///
    /// - parameters:
    ///   - predicate: A closure that takes an element as its parameter and returns a Boolean value that indicates whether
    /// publishing should continue.
    ///   - behavior: Whether or not to include the first element that doesn’t pass `predicate`.
    ///
    /// - returns: A publisher that passes through elements until the predicate indicates publishing should finish — and
    /// optionally that first `predicate`-failing element.
    func prefix(
        while predicate: @escaping (Output) -> Bool,
        behavior: PrefixWhileBehavior = .exclusive
    ) -> Publishers.InclusivePrefixWhile<Self> {
        return Publishers.InclusivePrefixWhile(upstream: self, behavior: behavior, predicate: predicate)
    }
}

// MARK: - PrefixWhileBehavior

/// Whether to include the first element that doesn’t pass
/// the `while` predicate passed to `Combine.Publisher.prefix(while:behavior:)`.
public enum PrefixWhileBehavior {
    /// Include the first element that doesn’t pass the `while` predicate.
    case inclusive

    /// Exclude the first element that doesn’t pass the `while` predicate.
    case exclusive
}

// MARK: - Publisher

public extension Publishers {
    struct InclusivePrefixWhile<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure

        private let upstream: Upstream
        private let behavior: PrefixWhileBehavior
        private let predicate: (Output) -> Bool

        public init(
            upstream: Upstream,
            behavior: PrefixWhileBehavior,
            predicate: @escaping (Output) -> Bool
        ) {
            self.upstream = upstream
            self.behavior = behavior
            self.predicate = predicate
        }

        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(
                subscription: Subscription(upstream: upstream, downstream: subscriber, behavior: behavior, predicate: predicate)
            )
        }
    }
}

// MARK: - Subscription

private extension Publishers.InclusivePrefixWhile {
    final class Subscription<Downstream: Subscriber>: ThreadSafeCancellable, Combine.Subscription
    where
        Downstream.Input == Upstream.Output,
        Downstream.Failure == Upstream.Failure
    {
        private var sink: Sink<Downstream>?

        init(
            upstream: Upstream,
            downstream: Downstream,
            behavior: PrefixWhileBehavior,
            predicate: @escaping (Output) -> Bool
        ) {
            self.sink = Sink(
                upstream: upstream,
                downstream: downstream,
                behavior: behavior,
                predicate: predicate
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

private extension Publishers.InclusivePrefixWhile {
    final class Sink<Downstream: Subscriber>: CombineKit.Sink<Upstream, Downstream>
    where
        Downstream.Input == Upstream.Output,
        Downstream.Failure == Upstream.Failure
    {
        private let behavior: PrefixWhileBehavior
        private let predicate: (Output) -> Bool

        init(
            upstream: Upstream,
            downstream: Downstream,
            behavior: PrefixWhileBehavior,
            predicate: @escaping (Output) -> Bool
        ) {
            self.behavior = behavior
            self.predicate = predicate
            super.init(upstream: upstream, downstream: downstream, transformFailure: { $0 })
        }

        override func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            // We have to override the default mechanism here to stop sequence when predicate return `false`.
            guard !predicate(input) else { return buffer.buffer(value: input) }

            switch behavior {
            case .inclusive:
                _ = buffer.buffer(value: input)
            case .exclusive:
                break
            }

            buffer.complete(completion: .finished)

            return .none
        }
    }
}
