//
//  UISchedulerTests.swift
//  CombineKitTests
//

import Combine
import CombineKit
import XCTest

final class UISchedulerTests: XCTestCase {
    private let testString1 = "First"
    private let testString2 = "Second"
    private let testString3 = "Third"

    private var subscription: AnyCancellable?
    private var values = [Event<String, Never>]()
    private var backgroundScheduler = DispatchQueue(label: "UISchedulerTestsQueue", target: .global())

    override func tearDown() {
        subscription?.cancel()
        values = []
        backgroundScheduler = DispatchQueue(label: "UISchedulerTestsQueue", target: .global())
    }

    func testScheduleOrderFromMain() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            UIScheduler.shared.schedule {
                self.values.append(.value(self.testString3))
                expectation.fulfill()
            }
            group.leave()
        }
        group.wait()

        UIScheduler.shared.schedule {
            self.values.append(.value(self.testString1))
            UIScheduler.shared.schedule {
                self.values.append(.value(self.testString2))
            }
        }

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(values, [.value(testString1), .value(testString2), .value(testString3)])
    }

    func testScheduleOrderFromBackground() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")
        expectation.expectedFulfillmentCount = 2

        let group = DispatchGroup()

        DispatchQueue.global().async {
            group.enter()
            DispatchQueue.main.async {
                group.wait()
                UIScheduler.shared.schedule {
                    self.values.append(.value(self.testString1))
                    expectation.fulfill()
                }
            }

            UIScheduler.shared.schedule {
                self.values.append(.value(self.testString2))
                expectation.fulfill()
            }
            group.leave()
        }

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(values, [.value(testString1), .value(testString2)])
    }

    func testExecutingThreadOfSubscribeOnMain() {
        subscription = AnyPublisher<String, Never> { subscriber in
            XCTAssertTrue(Thread.isMainThread)
            subscriber.send(self.testString1)
            subscriber.send(completion: .finished)
            return AnyCancellable {}
        }
        .subscribe(on: UIScheduler.shared)
        .sink { _ in
            XCTAssertTrue(Thread.isMainThread)
        } receiveValue: { _ in
            XCTAssertTrue(Thread.isMainThread)
        }
    }

    func testExecutingThreadOfSubscribeOnBackground() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")

        subscription = AnyPublisher<String, Never> { subscriber in
            XCTAssertTrue(Thread.isMainThread)
            subscriber.send(self.testString1)
            subscriber.send(completion: .finished)
            return AnyCancellable {}
        }
        .subscribe(on: UIScheduler.shared)
        .subscribe(on: backgroundScheduler)
        .sink { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        } receiveValue: { _ in
            XCTAssertTrue(Thread.isMainThread)
        }

        wait(for: [expectation], timeout: 1)
    }

    func testSubscribeOnMain() {
        subscription = Just(testString1)
            .subscribe(on: UIScheduler.shared)
            .print()
            .sink { _ in
                self.values.append(.finished)
            } receiveValue: {
                self.values.append(.value($0))
            }

        XCTAssertEqual(values, [.value(testString1), .finished])
    }

    func testSubscribeOnBackground() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")

        subscription = Just(testString1)
            .subscribe(on: UIScheduler.shared)
            .print()
            .subscribe(on: backgroundScheduler)
            .sink { _ in
                self.values.append(.finished)
                expectation.fulfill()
            } receiveValue: {
                self.values.append(.value($0))
            }

        XCTAssertEqual(values, [])

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(values, [.value(testString1), .finished])
    }

    func testReceiveOnMain() {
        subscription = Just(testString1)
            .receive(on: UIScheduler.shared)
            .sink { _ in
                self.values.append(.finished)
            } receiveValue: {
                self.values.append(.value($0))
            }

        XCTAssertEqual(values, [.value(testString1), .finished])
    }

    func testReceiveOnBackground() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")

        subscription = Just(testString1)
            .receive(on: backgroundScheduler)
            .receive(on: UIScheduler.shared)
            .sink { _ in
                self.values.append(.finished)
                expectation.fulfill()
            } receiveValue: {
                self.values.append(.value($0))
            }

        XCTAssertEqual(values, [])

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(values, [.value(testString1), .finished])
    }
}
