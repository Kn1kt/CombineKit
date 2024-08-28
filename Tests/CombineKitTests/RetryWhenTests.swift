//
//  RetryWhenTests.swift
//  CombineKitTests
//

import Combine
import CombineKit
import XCTest

class RetryWhenTests: XCTestCase {
    private var subscription: AnyCancellable!

    func testPassthroughNextAndComplete() {
        let source = PassthroughSubject<Int, MyError>()

        var resultOutput: Int?

        var completion: Subscribers.Completion<MyError>?

        subscription = source
            .retryWhen { error in
                error.filter { _ in false }
            }
            .sink(
                receiveCompletion: { completion = $0 },
                receiveValue: { resultOutput = $0 }
            )

        source.send(2)
        source.send(completion: .finished)

        XCTAssertEqual(resultOutput, 2)
        XCTAssertEqual(completion, .finished)
    }

    func testSuccessfulRetry() {
        var times = 0
        var retriesCount = 0

        var resultOutput: Int?

        var completion: Subscribers.Completion<RetryWhenTests.MyError>?

        subscription = Deferred(createPublisher: { () -> AnyPublisher<Int, MyError> in
            defer { times += 1 }
            if times == 0 {
                return Fail<Int, MyError>(error: MyError.someError).eraseToAnyPublisher()
            } else {
                return Just(5).setFailureType(to: MyError.self).eraseToAnyPublisher()
            }
        })
        .retryWhen { error in
            error
                .handleEvents(receiveOutput: { _ in retriesCount += 1 })
                .map { _ in }
        }
        .sink(
            receiveCompletion: { completion = $0 },
            receiveValue: { resultOutput = $0 }
        )

        XCTAssertEqual(resultOutput, 5)
        XCTAssertEqual(completion, .finished)
        XCTAssertEqual(times, 2)
        XCTAssertEqual(retriesCount, 1)
    }

    func testSuccessfulRetryWithManyRetries() {
        var times = 0
        var retriesCount = 0
        var subscriptionsCount = 0
        var cancelCount = 0
        var resultOutput: [Int] = []
        var completion: Subscribers.Completion<RetryWhenTests.MyError>?

        subscription = Deferred(createPublisher: { () -> AnyPublisher<Int, MyError> in
            defer { times += 1 }
            if times == 0 {
                return Fail<Int, MyError>(error: MyError.someError).eraseToAnyPublisher()
            } else {
                return Just(times)
                    .setFailureType(to: MyError.self)
                    .handleEvents(
                        receiveSubscription: { _ in subscriptionsCount += 1 },
                        receiveCancel: { cancelCount += 1 }
                    )
                    .eraseToAnyPublisher()
            }
        })
        .retryWhen { error in
            return error
                .handleEvents(receiveOutput: { _ in
                    retriesCount += 1
                })
                .map { _ in [1, 2].publisher }
                .switchToLatest()
        }
        .sink(
            receiveCompletion: { completion = $0 },
            receiveValue: { resultOutput.append($0) }
        )

        XCTAssertEqual(resultOutput, [2])
        XCTAssertEqual(completion, .finished)
        XCTAssertEqual(times, 3)
        XCTAssertEqual(retriesCount, 1)
        XCTAssertEqual(subscriptionsCount, 2)
        XCTAssertEqual(cancelCount, 1)
    }

    func testSuccessfulRetryWithCustomDemand() {
        var times = 0
        var retriesCount = 0
        var resultOutput: [Int] = []
        var completion: Subscribers.Completion<RetryWhenTests.MyError>?

        AnyPublisher<Int, MyError>.init { subscriber in
            defer { times += 1 }
            if times < 2 {
                subscriber.send(times)
                subscriber.send(completion: .failure(MyError.someError))
            } else {
                subscriber.send(times)
                subscriber.send(completion: .finished)
            }

            return AnyCancellable {}
        }
        .retryWhen { error in
            error
                .handleEvents(receiveOutput: { _ in retriesCount += 1 })
                .map { _ in }
        }
        .subscribe(
            AnySubscriber(
                receiveSubscription: { subscription in
                    self.subscription = AnyCancellable { subscription.cancel() }
                    subscription.request(.max(3))
                },
                receiveValue: {
                    resultOutput.append($0)
                    return .none
                },
                receiveCompletion: { completion = $0 }
            )
        )

        XCTAssertEqual(resultOutput, [0, 1, 2])
        XCTAssertEqual(completion, .finished)
        XCTAssertEqual(times, 3)
        XCTAssertEqual(retriesCount, 2)
    }

    func testRetryFailure() {
        var resultOutput: Int?

        var completion: Subscribers.Completion<RetryWhenTests.MyError>?

        subscription = Fail<Int, MyError>(error: MyError.someError)
            .retryWhen { error in
                error
                    .tryMap { _ in throw MyError.retryError }
                    .mapError { $0 as! MyError }
            }
            .sink(
                receiveCompletion: { completion = $0 },
                receiveValue: { resultOutput = $0 }
            )

        XCTAssertEqual(resultOutput, nil)
        XCTAssertEqual(completion, .failure(MyError.retryError))
    }

    func testRetryComplete() {
        var resultOutput: Int?

        var completion: Subscribers.Completion<RetryWhenTests.MyError>?

        subscription = Fail<Int, MyError>(error: MyError.someError)
            .retryWhen { error in
                error.prefix(1)
            }
            .sink(
                receiveCompletion: { completion = $0 },
                receiveValue: { resultOutput = $0 }
            )

        XCTAssertEqual(resultOutput, nil)
        XCTAssertEqual(completion, .finished)
    }

    enum MyError: Swift.Error {
        case someError
        case retryError
    }
}
