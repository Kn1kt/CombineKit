//
//  DematerializeTests.swift
//  CombineExtensions
//
//  Created by Shai Mishali on 14/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import Combine
import CombineExtensions
import XCTest

class DematerializeTests: XCTestCase {
    var subscription: AnyCancellable?
    var values = [String]()
    var completion: Subscribers.Completion<MyError>?
    var subject = PassthroughSubject<Event<String, MyError>, Never>()

    override func setUp() {
        values = []
        completion = nil
        subject = PassthroughSubject<Event<String, MyError>, Never>()
    }

    override func tearDown() {
        subscription?.cancel()
    }

    enum MyError: Swift.Error {
        case someError
    }

    func testEmpty() {
        subscription = subject
            .dematerialize()
            .sink(
                receiveCompletion: { self.completion = $0 },
                receiveValue: { self.values.append($0) }
            )

        subject.send(.finished)

        XCTAssertTrue(values.isEmpty)
        XCTAssertEqual(completion, .finished)
    }

    func testFail() {
        subscription = subject
            .dematerialize()
            .sink(
                receiveCompletion: { self.completion = $0 },
                receiveValue: { self.values.append($0) }
            )

        subject.send(.failure(.someError))

        XCTAssertTrue(values.isEmpty)
        XCTAssertEqual(completion, .failure(.someError))
    }

    func testFinished() {
        subscription = subject
            .dematerialize()
            .sink(
                receiveCompletion: { self.completion = $0 },
                receiveValue: { self.values.append($0) }
            )

        subject.send(.value("Hello"))
        subject.send(.value("There"))
        subject.send(.value("World!"))
        subject.send(.finished)

        XCTAssertEqual(values, ["Hello", "There", "World!"])
        XCTAssertEqual(completion, .finished)
    }

    func testFinishedLimitedDemand() {
        let subscriber = AnySubscriber(
            receiveSubscription: { subscription in
                subscription.request(.max(2))
                self.subscription = AnyCancellable(subscription)
            },
            receiveValue: { value in
                self.values.append(value)
                return .none
            },
            receiveCompletion: { finished in
                self.completion = finished
            }
        )

        subject
            .dematerialize()
            .receive(subscriber: subscriber)

        subject.send(.value("Hello"))
        subject.send(.value("There"))
        subject.send(.value("World!"))
        subject.send(.finished)

        XCTAssertEqual(values, ["Hello", "There"])
        XCTAssertEqual(completion, nil)
    }

    func testError() {
        subscription = subject
            .dematerialize()
            .sink(
                receiveCompletion: { self.completion = $0 },
                receiveValue: { self.values.append($0) }
            )

        subject.send(.value("Hello"))
        subject.send(.value("There"))
        subject.send(.value("World!"))
        subject.send(.failure(.someError))

        XCTAssertEqual(values, ["Hello", "There", "World!"])
        XCTAssertEqual(completion, .failure(.someError))
    }

    func testErrorLimitedDemand() {
        let subscriber = AnySubscriber(
            receiveSubscription: { subscription in
                subscription.request(.max(2))
                self.subscription = AnyCancellable(subscription)
            },
            receiveValue: { value in
                self.values.append(value)
                return .none
            },
            receiveCompletion: { finished in
                self.completion = finished
            }
        )

        subject
            .dematerialize()
            .receive(subscriber: subscriber)

        subject.send(.value("Hello"))
        subject.send(.value("There"))
        subject.send(.value("World!"))
        subject.send(.failure(.someError))

        XCTAssertEqual(values, ["Hello", "There"])
        XCTAssertEqual(completion, nil)
    }

    func testCancellUpstream() {
        var isCancelled = false
        var subject: Publishers.Create<Event<String, MyError>, Never>.Subscriber!

        subscription = AnyPublisher<Event<String, MyError>, Never>
            .create { subscriber in
                subject = subscriber
                return AnyCancellable { isCancelled = true }
            }
            .dematerialize()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        subject.send(.value("Hello"))
        subject.send(.value("There"))
        subject.send(.value("World!"))
        subject.send(.failure(.someError))

        XCTAssertTrue(isCancelled)
    }
}
