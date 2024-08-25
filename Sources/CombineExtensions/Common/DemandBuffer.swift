//
//  DemandBuffer.swift
//  CombineExtensions
//
//  Created by Shai Mishali on 21/02/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import Combine

/// A buffer responsible for managing the demand of a downstream
/// subscriber for an upstream publisher.
///
/// It buffers values and completion events and forwards them dynamically
/// according to the demand requested by the downstream.
///
/// In a sense, the subscription only relays the requests for demand, as well
/// the events emitted by the upstream — to this buffer, which manages
/// the entire behavior and backpressure contract.
final class DemandBuffer<S: Subscriber> {
    private let lock: some Locking = Locks.recursive
    private var buffer = [S.Input]()
    private let subscriber: S
    private var completion: Subscribers.Completion<S.Failure>?
    private var demandState = Demand()

    /// Initialize a new demand buffer for a provided downstream subscriber.
    ///
    /// - parameter subscriber: The downstream subscriber demanding events.
    init(subscriber: S) {
        self.subscriber = subscriber
    }

    /// Signal to the buffer that the upstream has changed.
    /// - Returns: A demand that has already been requested from the previous upstream, but has not yet been processed.
    func attachToNewUpstream() -> Subscribers.Demand {
        lock.lock()
        defer { lock.unlock() }

        demandState.sent = demandState.requested
        return demandState.requested - demandState.processed
    }

    /// Buffer an upstream value to later be forwarded to
    /// the downstream subscriber, once it demands it.
    ///
    /// - parameter value: Upstream value to buffer.
    ///
    /// - returns: The demand fulfilled by the buffer.
    func buffer(value: S.Input) -> Subscribers.Demand {
        guard completion == nil else {
            assertionFailure("Completed publisher can't sent values")
            return .none
        }

        lock.lock()
        defer { lock.unlock() }

        switch demandState.requested {
        case .unlimited:
            return subscriber.receive(value)
        default:
            buffer.append(value)
            return flush()
        }
    }

    /// Complete the demand buffer with an upstream completion event.
    ///
    /// This method will deplete the buffer immediately,
    /// based on the currently accumulated demand, and relay the
    /// completion event down as soon as demand is fulfilled.
    ///
    /// - parameter completion: Completion event.
    func complete(completion: Subscribers.Completion<S.Failure>) {
        guard self.completion == nil else {
            assertionFailure("Completion have already occurred")
            return
        }

        self.completion = completion
        _ = flush()
    }

    /// Signal to the buffer that the downstream requested new demand.
    ///
    /// - note: The buffer will attempt to flush as many events requested
    ///         by the downstream at this point.
    func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
        flush(adding: demand)
    }

    /// Flush buffered events to the downstream based on the current
    /// state of the downstream's demand.
    ///
    /// - parameter newDemand: The new demand to add. If `nil`, the flush isn't the
    ///                        result of an explicit demand change.
    ///
    /// - note: After fulfilling the downstream's request, if completion
    ///         has already occurred, the buffer will be cleared and the
    ///         completion event will be sent to the downstream subscriber.
    private func flush(adding newDemand: Subscribers.Demand? = nil) -> Subscribers.Demand {
        lock.lock()
        defer { lock.unlock() }

        if let newDemand {
            demandState.requested += newDemand
        }

        // If buffer isn't ready for flushing, return immediately.
        guard demandState.requested > 0 || newDemand == Subscribers.Demand.none else { return .none }

        while !buffer.isEmpty && demandState.processed < demandState.requested {
            demandState.requested += subscriber.receive(buffer.remove(at: 0))
            demandState.processed += 1
        }

        if let completion {
            // Completion event was already sent.
            buffer = []
            demandState = .init()
            self.completion = nil
            subscriber.receive(completion: completion)
            return .none
        }

        let sentDemand = demandState.requested - demandState.sent
        demandState.sent += sentDemand
        return sentDemand
    }
}

// MARK: - Private Helpers

private extension DemandBuffer {
    /// A model that tracks the downstream's accumulated demand state.
    struct Demand {
        var processed: Subscribers.Demand = .none
        var requested: Subscribers.Demand = .none
        var sent: Subscribers.Demand = .none
    }
}

// MARK: - Internally-scoped helpers

extension Subscription {
    /// Request demand if it's not empty.
    ///
    /// - parameter demand: Requested demand.
    func requestIfNeeded(_ demand: Subscribers.Demand) {
        guard demand > .none else { return }
        request(demand)
    }
}

extension Optional {
    /// Cancel the optional subscription and nullify it.
    mutating func kill() where Wrapped == Subscription {
        self?.cancel()
        self = nil
    }

    /// Cancel the optional cancellable and nullify it.
    mutating func kill() where Wrapped: Cancellable {
        self?.cancel()
        self = nil
    }

    /// Cancel the optional cancellable and nullify it.
    mutating func kill() where Wrapped == Cancellable {
        self?.cancel()
        self = nil
    }
}
