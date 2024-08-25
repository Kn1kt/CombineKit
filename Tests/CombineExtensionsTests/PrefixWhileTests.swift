//
//  PrefixWhileTests.swift
//  CombineExtensions
//

import Combine
import CombineExtensions
import XCTest

final class PrefixWhileTests: XCTestCase {
    private let subject = PassthroughSubject<Int, SomeError>()

    private var cancellable: AnyCancellable?
    private var values = [Int]()
    private var completions = [Subscribers.Completion<SomeError>]()

    func testExclusiveValueEventsWithFinished() {
        cancellable = subject
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .exclusive
            )
            .sink(
                receiveCompletion: { [unowned self] in completions.append($0) },
                receiveValue: { [unowned self] in values.append($0) }
            )

        [0, 2, 4, 5].forEach(subject.send)

        XCTAssertEqual(values, [0, 2, 4])
        XCTAssertEqual(completions, [.finished])
    }

    func testExclusiveValueEventsWithError() {
        cancellable = subject
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .exclusive
            )
            .sink(
                receiveCompletion: { [unowned self] in completions.append($0) },
                receiveValue: { [unowned self] in values.append($0) }
            )

        [0, 2, 4].forEach(subject.send)

        subject.send(completion: .failure(.init()))

        XCTAssertEqual(values, [0, 2, 4])
        XCTAssertEqual(completions, [.failure(.init())])
    }

    func testInclusiveValueEventsWithStopElement() {
        cancellable = subject
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .inclusive
            )
            .sink(
                receiveCompletion: { [unowned self] in completions.append($0) },
                receiveValue: { [unowned self] in values.append($0) }
            )

        [0, 2, 4, 5].forEach(subject.send)

        XCTAssertEqual(values, [0, 2, 4, 5])
        XCTAssertEqual(completions, [.finished])
    }

    func testInclusiveValueEventsWithErrorAfterStopElement() {
        cancellable = subject
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .inclusive
            )
            .sink(
                receiveCompletion: { [unowned self] in completions.append($0) },
                receiveValue: { [unowned self] in values.append($0) }
            )

        [0, 2, 4, 5].forEach(subject.send)

        subject.send(completion: .failure(.init()))

        XCTAssertEqual(values, [0, 2, 4, 5])
        XCTAssertEqual(completions, [.finished])
    }

    func testInclusiveValueEventsWithErrorBeforeStop() {
        cancellable = subject
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .inclusive
            )
            .sink(
                receiveCompletion: { [unowned self] in completions.append($0) },
                receiveValue: { [unowned self] in values.append($0) }
            )

        [0, 2, 4].forEach(subject.send)

        subject.send(completion: .failure(.init()))

        XCTAssertEqual(values, [0, 2, 4])
        XCTAssertEqual(completions, [.failure(.init())])
    }

    func testInclusiveEarlyCompletion() {
        cancellable = subject
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .inclusive
            )
            .sink(
                receiveCompletion: { [unowned self] in completions.append($0) },
                receiveValue: { [unowned self] in values.append($0) }
            )

        [0, 2, 4].forEach(subject.send)

        subject.send(completion: .finished)

        XCTAssertEqual(values, [0, 2, 4])
        XCTAssertEqual(completions, [.finished])
    }

    func testExclusiveCancellUpstream() {
        var isCancelled = false
        var subject: Publishers.Create<Int, Never>.Subscriber!

        cancellable = AnyPublisher<Int, Never>
            .create { subscriber in
                subject = subscriber
                return AnyCancellable { isCancelled = true }
            }
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .exclusive
            )
            .sink { _ in }

        [0, 2, 4, 5].forEach(subject.send)

        XCTAssertTrue(isCancelled)
    }

    func testInclusiveCancellUpstream() {
        var isCancelled = false
        var subject: Publishers.Create<Int, Never>.Subscriber!

        cancellable = AnyPublisher<Int, Never>
            .create { subscriber in
                subject = subscriber
                return AnyCancellable { isCancelled = true }
            }
            .prefix(
                while: { $0 % 2 == 0 },
                behavior: .inclusive
            )
            .sink { _ in }

        [0, 2, 4, 5].forEach(subject.send)

        XCTAssertTrue(isCancelled)
    }
}

// MARK: - Helpers

private struct SomeError: Error, Equatable {}
