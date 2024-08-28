//
//  SinkTests.swift
//  CombineKit
//

import Combine
@testable import CombineKit
import XCTest

final class SinkTests: XCTestCase {
    private var cancellable: ThreadSafeCancellable!

    private var values = [Int]()
    private var completions = [Subscribers.Completion<SomeError>]()

    func testReceiveSubscription() {
        let publisher = AnyPublisher<Int, SomeError> { subscriber in
            subscriber.send(1)
            subscriber.send(2)
            subscriber.send(completion: .finished)

            return AnyCancellable {}
        }

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        sink.demand(.max(1))

        XCTAssertEqual([1], values)
        XCTAssertEqual([.finished], completions)
    }

    func testReceiveMultipleSubscription() {
        var counter = 1
        let publisher = AnyPublisher<Int, SomeError> { subscriber in
            (0 ..< counter).forEach {
                subscriber.send($0)
            }
            counter += 1

            return AnyCancellable {}
        }

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)
        sink.demand(.max(2))
        XCTAssertEqual([0], values)

        publisher.subscribe(sink)
        XCTAssertEqual([0, 0], values)

        publisher.subscribe(sink)
        sink.demand(.unlimited)
        XCTAssertEqual([0, 0, 0, 1, 2], values)

        XCTAssertEqual([], completions)
        XCTAssertEqual(4, counter)
    }

    func testRecursiveReceiveSubscription() {
        var sink: Sink<AnyPublisher<Int, SomeError>, AnySubscriber<Int, SomeError>>!

        let publisher = AnyPublisher<Int, SomeError> { subscriber in
            subscriber.send(1)
            return AnyCancellable {}
        }

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)

            if values.count < 2 {
                publisher.subscribe(sink)
            }

            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        sink.demand(.max(2))

        XCTAssertEqual([1, 1], values)
        XCTAssertEqual([], completions)
    }

    func testRecursiveReceiveSubscription2() {
        var sink: Sink<AnyPublisher<Int, SomeError>, AnySubscriber<Int, SomeError>>!

        let publisher = AnyPublisher<Int, SomeError> { subscriber in
            subscriber.send(1)
            subscriber.send(completion: .finished)
            return AnyCancellable {}
        }

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)

            if values.count < 2 {
                publisher.subscribe(sink)
            }

            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        sink.demand(.max(2))

        XCTAssertEqual([1, 1], values)
        XCTAssertEqual([.finished], completions)
    }

    func testRecursiveReceiveSubscription3() {
        var sink: Sink<AnyPublisher<Int, SomeError>, AnySubscriber<Int, SomeError>>!

        let publisher = AnyPublisher<Int, SomeError> { subscriber in
            subscriber.send(1)
            subscriber.send(completion: .finished)
            return AnyCancellable {}
        }

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
            publisher.subscribe(sink)
        }

        sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        sink.demand(.max(2))

        XCTAssertEqual([1], values)
        XCTAssertEqual([.finished], completions)
    }

    func testDemand() {
        let publisher = (1 ... 10).publisher
            .setFailureType(to: SomeError.self)

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        sink.demand(.max(1))
        XCTAssertEqual([1], values)
        XCTAssertEqual([], completions)

        sink.demand(.max(8))
        XCTAssertEqual((1 ... 9).map { $0 }, values)
        XCTAssertEqual([], completions)

        sink.demand(.max(1))
        XCTAssertEqual((1 ... 10).map { $0 }, values)
        XCTAssertEqual([.finished], completions)

        sink.demand(.unlimited)

        XCTAssertEqual((1 ... 10).map { $0 }, values)
        XCTAssertEqual([.finished], completions)
    }

    func testConcurrentDemand() {
        let finishExpectation = expectation(description: "Publisher Finished")
        let publisher = (1 ... 10).publisher
            .flatMap { Just($0) }
            .setFailureType(to: SomeError.self)

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
            finishExpectation.fulfill()
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        (1 ... 10).forEach { _ in
            DispatchQueue.global().async {
                sink.demand(.max(1))
            }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual((1 ... 10).map { $0 }, values)
        XCTAssertEqual([.finished], completions)
    }

    func testDemandBeforeReceiveSubscription() {
        let publisher = (1 ... 10).publisher
            .setFailureType(to: SomeError.self)

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        sink.demand(.max(1))

        publisher.subscribe(sink)

        XCTAssertEqual([1], values)
        XCTAssertEqual([], completions)

        sink.demand(.max(9))

        XCTAssertEqual((1 ... 10).map { $0 }, values)
        XCTAssertEqual([.finished], completions)
    }

    func testReceiveInput() {
        let publisher = (1 ... 10).publisher
            .setFailureType(to: SomeError.self)

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(
            upstream: publisher,
            downstream: subscriber,
            transformOutput: { value in
                value - 1
            }
        )
        cancellable = sink

        publisher.subscribe(sink)
        sink.demand(.unlimited)

        XCTAssertEqual((0 ... 9).map { $0 }, values)
        XCTAssertEqual([.finished], completions)
    }

    func testReceiveCompletion() {
        let publisher = AnyPublisher<Int, SomeError> { subscriber in
            subscriber.send(1)
            subscriber.send(2)
            subscriber.send(completion: .finished)

            return AnyCancellable {}
        }

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)
        sink.demand(.max(1))

        XCTAssertEqual([1], values)
        XCTAssertEqual([.finished], completions)
    }

    func testReceiveCompletionWithFailure() {
        let publisher = Fail<Int, OtherError>(error: OtherError())

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(
            upstream: publisher,
            downstream: subscriber,
            transformFailure: { _ in SomeError() }
        )
        cancellable = sink

        publisher.subscribe(sink)
        sink.demand(.unlimited)

        XCTAssertEqual([], values)
        XCTAssertEqual([.failure(SomeError())], completions)
    }

    func testCancel() {
        let publisher = Just(1)
            .setFailureType(to: SomeError.self)

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        sink.cancel()

        sink.demand(.unlimited)

        XCTAssertEqual([], values)
        XCTAssertEqual([], completions)
    }

    func testCancel2() {
        let finishExpectation = expectation(description: "Test Finished")
        finishExpectation.expectedFulfillmentCount = 3

        let publisher = Just(1)
            .setFailureType(to: SomeError.self)

        let subscriber = AnySubscriber<Int, SomeError> { subscription in
            XCTFail("Unexpected Subscription \(subscription)")
        } receiveValue: { [unowned self] value in
            values.append(value)
            return .none
        } receiveCompletion: { [unowned self] completion in
            completions.append(completion)
        }

        let sink = Sink(forwardingFrom: publisher, to: subscriber)
        cancellable = sink

        publisher.subscribe(sink)

        DispatchQueue.global().async {
            sink.demand(.unlimited)
            finishExpectation.fulfill()
        }

        DispatchQueue.global().async {
            sink.cancel()
            finishExpectation.fulfill()
        }

        DispatchQueue.global().async {
            sink.cancel()
            finishExpectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        let firstCase = values.isEmpty && completions.isEmpty
        let secondCase = values == [1] && completions == [.finished]

        XCTAssertNotEqual(firstCase, secondCase)
    }
}

private struct SomeError: Error, Equatable {}
private struct OtherError: Error, Equatable {}
