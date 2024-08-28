//
//  CurrentValuePublisher.swift
//  CombineKit
//

import Combine

public protocol CurrentValuePublisher<Output, Failure>: Publisher {
    var value: Output { get }
}

extension CurrentValueSubject: CurrentValuePublisher {}

// MARK: - AnyCurrentValuePublisher

public struct AnyCurrentValuePublisher<Output, Failure: Error>: CurrentValuePublisher {
    public var value: Output { publisher.value }

    private let publisher: any CurrentValuePublisher<Output, Failure>

    public init(_ publisher: any CurrentValuePublisher<Output, Failure>) {
        self.publisher = publisher
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        publisher.receive(subscriber: subscriber)
    }
}

public extension CurrentValuePublisher {
    func eraseToAnyPublisher() -> AnyCurrentValuePublisher<Output, Failure> {
        return AnyCurrentValuePublisher(self)
    }
}
