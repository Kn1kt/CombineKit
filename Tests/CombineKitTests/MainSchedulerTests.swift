//
//  MainSchedulerTests.swift
//  CombineKitTests
//

import Combine
import CombineKit
import XCTest

final class MainSchedulerTests: XCTestCase {
    private let testString1 = "First"
    private let testString2 = "Second"
    private let testString3 = "Third"
    private let testString4 = "Forth"

    private var subscription: AnyCancellable?
    private var values = [Event<String, Never>]()
    private var mainScheduler = MainScheduler()
    private var backgroundScheduler = DispatchQueue(label: "MainSchedulerTestsQueue", target: .global())

    override func tearDown() {
        subscription?.cancel()
        values = []
        mainScheduler = MainScheduler()
        backgroundScheduler = DispatchQueue(label: "MainSchedulerTestsQueue", target: .global())
    }

    func testIsPerformingCurrentAction() {
        XCTAssertFalse(mainScheduler.isPerformingCurrentAction)
        mainScheduler.schedule {
            XCTAssertTrue(self.mainScheduler.isPerformingCurrentAction)
        }
        XCTAssertFalse(mainScheduler.isPerformingCurrentAction)
    }

    func testScheduleOrder() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")
        let group = DispatchGroup()

        DispatchQueue.global().async {
            group.enter()
            DispatchQueue.main.async {
                group.wait()
                self.mainScheduler.schedule {
                    self.values.append(.value(self.testString2))
                    expectation.fulfill()
                }
            }

            self.mainScheduler.schedule {
                self.values.append(.value(self.testString1))
            }
            group.leave()
        }

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(values, [.value(testString1), .value(testString2)])
    }

    func testRecursiveScheduleOrder() {
        let expectation = expectation(description: "Wait Until Completed \(#function)")
        let group = DispatchGroup()

        mainScheduler.schedule {
            self.values.append(.value(self.testString1))

            group.enter()
            DispatchQueue.global().async {
                self.mainScheduler.schedule {
                    self.values.append(.value(self.testString4))
                    expectation.fulfill()
                }
                group.leave()
            }
            group.wait()

            self.mainScheduler.schedule {
                self.values.append(.value(self.testString2))
                self.mainScheduler.schedule {
                    self.values.append(.value(self.testString3))
                }
            }
        }

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(values, [.value(testString1), .value(testString2), .value(testString3), .value(testString4)])
    }

    func testExecutingThreadOfSubscribeOnMain() {
        subscription = AnyPublisher<String, Never> { subscriber in
            XCTAssertTrue(Thread.isMainThread)
            subscriber.send(self.testString1)
            subscriber.send(completion: .finished)
            return AnyCancellable {}
        }
        .subscribe(on: mainScheduler)
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
        .subscribe(on: mainScheduler)
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
            .subscribe(on: mainScheduler)
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
            .subscribe(on: mainScheduler)
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
            .receive(on: mainScheduler)
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
            .receive(on: mainScheduler)
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
