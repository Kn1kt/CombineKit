//
//  RetryWhen.swift
//  CombineKit
//

import Combine

// MARK: - Operator methods

public extension Publisher {
    /// Repeats the source publisher on error when the notifier emits a next value.
    /// If the source publisher errors and the notifier completes, it will complete the source sequence.
    ///
    /// - Parameter notificationHandler: A handler that is passed a publisher of errors raised by the source publisher and returns
    /// a publisher that either continues,
    /// completes or errors.
    /// This behavior is then applied to the source publisher.
    ///
    /// - Returns: A publisher producing the elements of the given sequence repeatedly until it terminates successfully
    /// or is notified to error or complete.
    func retryWhen<RetryTrigger>(
        _ errorTrigger: @escaping (AnyPublisher<Self.Failure, Never>) -> RetryTrigger
    ) -> Publishers.RetryWhen<Self, RetryTrigger>
    where
        RetryTrigger: Publisher,
        RetryTrigger.Failure == Failure
    {
        return .init(upstream: self, errorTrigger: errorTrigger)
    }

    /// Repeats the source publisher on error when the notifier emits a next value.
    /// If the source publisher errors and the notifier completes, it will complete the source sequence.
    ///
    /// - Parameter notificationHandler: A handler that is passed a publisher of errors raised by the source publisher and returns
    /// a publisher that either continues
    /// or completes.
    /// This behavior is then applied to the source publisher.
    ///
    /// - Returns: A publisher producing the elements of the given sequence repeatedly until it terminates successfully
    /// or is notified to error or complete.
    func retryWhen<RetryTrigger>(
        _ errorTrigger: @escaping (AnyPublisher<Self.Failure, Never>) -> RetryTrigger
    ) -> Publishers.RetryWhen<Self, RetryTrigger>
    where
        RetryTrigger: Publisher,
        RetryTrigger.Failure == Never
    {
        return .init(upstream: self, errorTrigger: errorTrigger)
    }
}

// MARK: - Publisher

public extension Publishers {
    struct RetryWhen<Upstream, RetryTrigger>: Publisher where Upstream: Publisher, RetryTrigger: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        typealias ErrorTrigger = (AnyPublisher<Upstream.Failure, Never>) -> RetryTrigger

        private let upstream: Upstream
        private let errorTrigger: ErrorTrigger

        init(upstream: Upstream, errorTrigger: @escaping ErrorTrigger) {
            self.upstream = upstream
            self.errorTrigger = errorTrigger
        }

        public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Subscription(upstream: upstream, downstream: subscriber, errorTrigger: errorTrigger))
        }
    }
}

// MARK: - Subscription

private extension Publishers.RetryWhen {
    final class Subscription<Downstream: Subscriber>: ThreadSafeCancellable, Combine.Subscription
    where
        Downstream.Input == Upstream.Output,
        Downstream.Failure == Upstream.Failure
    {
        private let upstream: Upstream
        private let downstream: Downstream
        private let errorSubject = PassthroughSubject<Upstream.Failure, Never>()
        private var sink: Sink<Upstream, Downstream>?
        private var cancellable: AnyCancellable?

        init(
            upstream: Upstream,
            downstream: Downstream,
            errorTrigger: @escaping (AnyPublisher<Upstream.Failure, Never>) -> RetryTrigger
        ) {
            self.upstream = upstream
            self.downstream = downstream
            self.sink = Sink(
                upstream: upstream,
                downstream: downstream,
                transformOutput: { $0 },
                transformFailure: { [errorSubject] in
                    errorSubject.send($0)
                    return nil
                }
            )
            self.cancellable = errorTrigger(errorSubject.eraseToAnyPublisher())
                .sink(
                    receiveCompletion: { [sink] completion in
                        switch completion {
                        case .finished:
                            sink?.buffer.complete(completion: .finished)
                        case let .failure(error):
                            if let error = error as? Downstream.Failure {
                                sink?.buffer.complete(completion: .failure(error))
                            }
                        }
                    },
                    receiveValue: { [upstream, sink] _ in
                        guard let sink else { return }
                        upstream.subscribe(sink)
                    }
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
                cancellable.kill()
                sink.kill()
            }
        }
    }
}

extension Publishers.RetryWhen.Subscription: CustomStringConvertible {
    var description: String {
        return "RetryWhen.Subscription<\(Downstream.Input.self), \(Downstream.Failure.self)>"
    }
}
