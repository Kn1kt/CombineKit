//
//  WithLatestFromTests.swift
//  CombineKitTests
//
//  Created by Shai Mishali on 24/10/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import Combine
import CombineKit
import XCTest

class WithLatestFromTests: XCTestCase {
    var subscription: AnyCancellable!
    func testWithResultSelector() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        var results = [String]()
        var completed = false

        subscription = subject1
            .withLatestFrom(subject2) { "\($0)\($1)" }
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append($0) }
            )

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)
        subject2.send("bar")
        subject1.send(4)
        subject1.send(5)
        subject2.send("foo")
        subject1.send(6)
        subject2.send("qux")
        subject1.send(7)
        subject1.send(8)
        subject1.send(9)

        XCTAssertEqual(
            results,
            [
                "4bar",
                "5bar",
                "6foo",
                "7qux",
                "8qux",
                "9qux",
            ]
        )

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
    }

    // We have to hold a reference to the subscription or the
    // publisher will get deallocated and canceled
    var demandSubscription: Subscription!
    func testWithResultSelectorLimitedDemand() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        var results = [String]()
        var completed = false

        let subscriber = AnySubscriber<String, Never>(
            receiveSubscription: { subscription in
                self.demandSubscription = subscription
                subscription.request(.max(3))
            },
            receiveValue: { val in
                results.append(val)
                return .none
            },
            receiveCompletion: { _ in completed = true }
        )

        subject1
            .withLatestFrom(subject2) { "\($0)\($1)" }
            .subscribe(subscriber)

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)
        subject2.send("bar")
        subject1.send(4)
        subject1.send(5)
        subject2.send("foo")
        subject1.send(6)
        subject2.send("qux")
        subject1.send(7)
        subject1.send(8)
        subject1.send(9)

        XCTAssertEqual(results, ["4bar", "5bar", "6foo"])

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
    }

    func testWithResultSelectorDoesNotRetainClassBasedPublisher() {
        var subject1: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        var subject2: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        weak var weakSubject1: PassthroughSubject<Int, Never>? = subject1
        weak var weakSubject2: PassthroughSubject<String, Never>? = subject2

        var results = [String]()

        subscription = subject1?
            .withLatestFrom(subject2!) { "\($0)\($1)" }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append($0) }
            )

        subject1?.send(1)
        subject2?.send("bar")
        subject1?.send(2)

        XCTAssertEqual(results, ["2bar"])

        subscription = nil
        subject1 = nil
        subject2 = nil
        XCTAssertNil(weakSubject1)
        XCTAssertNil(weakSubject2)
    }

    func testWithResultSelectorDoesNotRetainClassBasedPublisherWithoutSendCompletion() {
        var upstream: AnyPublisher? = Just("1")
            .setFailureType(to: Never.self)
            .eraseToAnyPublisher()
        var other: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        weak var weakOther: PassthroughSubject<String, Never>? = other

        var results = [String]()

        subscription = upstream?
            .withLatestFrom(other!) { "\($0)\($1)" }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append($0) }
            )

        other?.send("foo")
        XCTAssertEqual(results, ["1foo"])

        subscription = nil
        upstream = nil
        other = nil
        XCTAssertNil(weakOther)
    }

    func testNoResultSelector() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        var results = [String]()
        var completed = false

        subscription = subject1
            .withLatestFrom(subject2)
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append($0) }
            )

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)
        subject2.send("bar")
        subject1.send(4)
        subject1.send(5)
        subject2.send("foo")
        subject1.send(6)
        subject2.send("qux")
        subject1.send(7)
        subject1.send(8)
        subject1.send(9)

        XCTAssertEqual(
            results,
            [
                "bar",
                "bar",
                "foo",
                "qux",
                "qux",
                "qux",
            ]
        )

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
        subscription.cancel()
    }

    func testNoResultSelectorDoesNotRetainClassBasedPublisher() {
        var subject1: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        var subject2: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        weak var weakSubject1: PassthroughSubject<Int, Never>? = subject1
        weak var weakSubject2: PassthroughSubject<String, Never>? = subject2

        var results = [String]()

        subscription = subject1?
            .withLatestFrom(subject2!)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append($0) }
            )

        subject1?.send(1)
        subject2?.send("bar")
        subject1?.send(4)

        XCTAssertEqual(results, ["bar"])

        subscription = nil
        subject1 = nil
        subject2 = nil
        XCTAssertNil(weakSubject1)
        XCTAssertNil(weakSubject2)
    }

    func testWithLatestFrom2WithResultSelector() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Bool, Never>()
        var results = [String]()
        var completed = false

        subscription = subject1
            .withLatestFrom(subject2, subject3) { "\($0)|\($1.0)|\($1.1)" }
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append($0) }
            )

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)

        subject2.send("bar")

        subject1.send(4)
        subject1.send(5)

        subject3.send(true)

        subject1.send(10)

        subject2.send("foo")

        subject1.send(6)

        subject2.send("qux")

        subject3.send(false)

        subject1.send(7)
        subject1.send(8)
        subject1.send(9)

        XCTAssertEqual(
            results,
            [
                "10|bar|true",
                "6|foo|true",
                "7|qux|false",
                "8|qux|false",
                "9|qux|false",
            ]
        )

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject3.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
    }

    func testWithLatestFrom2WithResultSectorDoesNotRetainPublisher() {
        var subject1: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        var subject2: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        var subject3: PassthroughSubject<Bool, Never>? = PassthroughSubject<Bool, Never>()
        weak var weakSubject1: PassthroughSubject<Int, Never>? = subject1
        weak var weakSubject2: PassthroughSubject<String, Never>? = subject2
        weak var weakSubject3: PassthroughSubject<Bool, Never>? = subject3

        var results = [String]()

        subscription = subject1?
            .withLatestFrom(subject2!, subject3!) { "\($0)|\($1.0)|\($1.1)" }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append($0) }
            )

        subject2?.send("bar")
        subject3?.send(true)
        subject1?.send(10)

        XCTAssertEqual(results, ["10|bar|true"])

        subscription = nil
        subject1 = nil
        subject2 = nil
        subject3 = nil
        XCTAssertNil(weakSubject1)
        XCTAssertNil(weakSubject2)
        XCTAssertNil(weakSubject3)
    }

    func testWithLatestFrom2WithNoResultSelector() {
        struct Result: Equatable {
            let string: String
            let boolean: Bool
        }

        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Bool, Never>()
        var results = [Result]()
        var completed = false

        subscription = subject1
            .withLatestFrom(subject2, subject3)
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append(Result(string: $0.0, boolean: $0.1)) }
            )

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)

        subject2.send("bar")

        subject1.send(4)
        subject1.send(5)

        subject3.send(true)

        subject1.send(10)

        subject2.send("foo")

        subject1.send(6)

        subject2.send("qux")

        subject3.send(false)

        subject1.send(7)
        subject1.send(8)
        subject1.send(9)

        XCTAssertEqual(
            results,
            [
                Result(string: "bar", boolean: true),
                Result(string: "foo", boolean: true),
                Result(string: "qux", boolean: false),
                Result(string: "qux", boolean: false),
                Result(string: "qux", boolean: false),
            ]
        )

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject3.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
    }

    func testWithLatestFrom2WithNoResultSectorDoesNotRetainPublisher() {
        var subject1: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        var subject2: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        var subject3: PassthroughSubject<Bool, Never>? = PassthroughSubject<Bool, Never>()
        weak var weakSubject1: PassthroughSubject<Int, Never>? = subject1
        weak var weakSubject2: PassthroughSubject<String, Never>? = subject2
        weak var weakSubject3: PassthroughSubject<Bool, Never>? = subject3

        var results = [String]()

        subscription = subject1?
            .withLatestFrom(subject2!, subject3!)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append("\($0.0)|\($0.1)") }
            )

        subject2?.send("bar")
        subject3?.send(true)
        subject1?.send(10)

        XCTAssertEqual(results, ["bar|true"])

        subscription = nil
        subject1 = nil
        subject2 = nil
        subject3 = nil
        XCTAssertNil(weakSubject1)
        XCTAssertNil(weakSubject2)
        XCTAssertNil(weakSubject3)
    }

    func testWithLatestFrom3WithResultSelector() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Bool, Never>()
        let subject4 = PassthroughSubject<Int, Never>()

        var results = [String]()
        var completed = false

        subscription = subject1
            .withLatestFrom(subject2, subject3, subject4) { "\($0)|\($1.0)|\($1.1)|\($1.2)" }
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append($0) }
            )

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)

        subject2.send("bar")

        subject1.send(4)
        subject1.send(5)

        subject3.send(true)
        subject4.send(5)

        subject1.send(10)
        subject4.send(7)

        subject2.send("foo")

        subject1.send(6)

        subject2.send("qux")

        subject3.send(false)

        subject1.send(7)
        subject1.send(8)
        subject4.send(8)
        subject3.send(true)
        subject1.send(9)

        XCTAssertEqual(
            results,
            [
                "10|bar|true|5",
                "6|foo|true|7",
                "7|qux|false|7",
                "8|qux|false|7",
                "9|qux|true|8",
            ]
        )

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject3.send(completion: .finished)
        XCTAssertFalse(completed)
        subject4.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
    }

    func testWithLatestFrom3WithResultSectorDoesNotRetainPublisher() {
        var subject1: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        var subject2: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        var subject3: PassthroughSubject<Bool, Never>? = PassthroughSubject<Bool, Never>()
        var subject4: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        weak var weakSubject1: PassthroughSubject<Int, Never>? = subject1
        weak var weakSubject2: PassthroughSubject<String, Never>? = subject2
        weak var weakSubject3: PassthroughSubject<Bool, Never>? = subject3
        weak var weakSubject4: PassthroughSubject<Bool, Never>? = subject3

        var results = [String]()

        subscription = subject1?
            .withLatestFrom(subject2!, subject3!, subject4!) { "\($0)|\($1.0)|\($1.1)|\($1.2)" }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append($0) }
            )

        subject2?.send("bar")
        subject3?.send(true)
        subject4?.send(100)

        subject1?.send(10)

        XCTAssertEqual(results, ["10|bar|true|100"])

        subscription = nil
        subject1 = nil
        subject2 = nil
        subject3 = nil
        subject4 = nil
        XCTAssertNil(weakSubject1)
        XCTAssertNil(weakSubject2)
        XCTAssertNil(weakSubject3)
        XCTAssertNil(weakSubject4)
    }

    func testWithLatestFrom3WithNoResultSelector() {
        struct Result: Equatable {
            let string: String
            let boolean: Bool
            let integer: Int
        }

        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<String, Never>()
        let subject3 = PassthroughSubject<Bool, Never>()
        let subject4 = PassthroughSubject<Int, Never>()

        var results = [Result]()
        var completed = false

        subscription = subject1
            .withLatestFrom(subject2, subject3, subject4)
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append(Result(string: $0.0, boolean: $0.1, integer: $0.2)) }
            )

        subject1.send(1)
        subject1.send(2)
        subject1.send(3)

        subject2.send("bar")

        subject1.send(4)
        subject1.send(5)

        subject3.send(true)
        subject4.send(5)

        subject1.send(10)
        subject4.send(7)

        subject2.send("foo")

        subject1.send(6)

        subject2.send("qux")

        subject3.send(false)

        subject1.send(7)
        subject1.send(8)
        subject4.send(8)
        subject3.send(true)
        subject1.send(9)

        XCTAssertEqual(
            results,
            [
                Result(string: "bar", boolean: true, integer: 5),
                Result(string: "foo", boolean: true, integer: 7),
                Result(string: "qux", boolean: false, integer: 7),
                Result(string: "qux", boolean: false, integer: 7),
                Result(string: "qux", boolean: true, integer: 8),
            ]
        )

        XCTAssertFalse(completed)
        subject2.send(completion: .finished)
        XCTAssertFalse(completed)
        subject3.send(completion: .finished)
        XCTAssertFalse(completed)
        subject4.send(completion: .finished)
        XCTAssertFalse(completed)
        subject1.send(completion: .finished)
        XCTAssertTrue(completed)
    }

    func testWithLatestFrom3WithNoResultSectorDoesNotRetainPublisher() {
        var subject1: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        var subject2: PassthroughSubject<String, Never>? = PassthroughSubject<String, Never>()
        var subject3: PassthroughSubject<Bool, Never>? = PassthroughSubject<Bool, Never>()
        var subject4: PassthroughSubject<Int, Never>? = PassthroughSubject<Int, Never>()
        weak var weakSubject1: PassthroughSubject<Int, Never>? = subject1
        weak var weakSubject2: PassthroughSubject<String, Never>? = subject2
        weak var weakSubject3: PassthroughSubject<Bool, Never>? = subject3
        weak var weakSubject4: PassthroughSubject<Bool, Never>? = subject3

        var results = [String]()

        subscription = subject1?
            .withLatestFrom(subject2!, subject3!, subject4!)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results.append("\($0.0)|\($0.1)|\($0.2)") }
            )

        subject2?.send("bar")
        subject3?.send(true)
        subject4?.send(100)

        subject1?.send(10)

        XCTAssertEqual(results, ["bar|true|100"])

        subscription = nil
        subject1 = nil
        subject2 = nil
        subject3 = nil
        subject4 = nil
        XCTAssertNil(weakSubject1)
        XCTAssertNil(weakSubject2)
        XCTAssertNil(weakSubject3)
        XCTAssertNil(weakSubject4)
    }

    /// This test is trying to get a data race between `send()` invocations.
    func testAsyncReceiveValues() {
        let subject = PassthroughSubject<NSObject, Never>()
        let otherSubject = PassthroughSubject<NSObject, Never>()
        let expectation = expectation(description: "Wait Until Completed \(#function)")
        expectation.expectedFulfillmentCount = 2

        let expectedResult = 10000
        var result = 0

        subscription = subject
            .withLatestFrom(otherSubject) { ($0, $1) }
            .receive(on: MainScheduler.shared)
            .sink { _, _ in result += 1 }

        otherSubject.send(NSObject())

        DispatchQueue.global().async {
            (1 ... expectedResult).forEach { _ in otherSubject.send(NSObject()) }
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        DispatchQueue.global().async {
            (1 ... expectedResult).forEach { _ in subject.send(NSObject()) }
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, expectedResult)

        subscription = nil
    }

    /// This test is trying to get a data race between `receiveSubscription(:)` and `cancel()`.
    /// To get stable results, it should be run approximately 100 000 times.
    func testAsyncCancel() {
        let subject = CurrentValueSubject<Int, Never>(0)
        let otherSubject = PassthroughSubject<Int, Never>()
        let group = DispatchGroup()
        let extpectation = expectation(description: "Wait Until Completed \(#function)")
        extpectation.expectedFulfillmentCount = 2

        var results = [Int]()

        subscription = subject
            .withLatestFrom(otherSubject) { ($0, $1) }
            .handleEvents(
                receiveSubscription: { _ in
                    group.enter()
                    group.enter()

                    DispatchQueue.global().async {
                        group.leave()
                        self.subscription?.cancel()

                        extpectation.fulfill()
                    }

                    DispatchQueue.global().async {
                        group.leave()
                        otherSubject.send(1)

                        extpectation.fulfill()
                    }
                    group.wait()
                }
            )
            .sink { lhs, rhs in
                results.append(lhs)
                results.append(rhs)
            }

        wait(for: [extpectation], timeout: 1)
        if results != [], results != [0, 1] {
            XCTFail("Unexpected Result: \(results)")
        }

        subscription = nil
    }

    func testAsyncCancelRepeatedly() {
        (1 ... 10000).forEach { _ in testAsyncCancel() }
    }
}
