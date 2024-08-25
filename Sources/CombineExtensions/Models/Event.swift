//
//  Event.swift
//  CombineExtensions
//
//  Created by Shai Mishali on 13/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import Foundation

/// Represents a Combine Event.
public enum Event<Output, Failure: Swift.Error> {
    case value(Output)
    case failure(Failure)
    case finished

    /// Returns a new event, mapping any value using the given
    /// transformation.
    ///
    /// Use this method when you need to transform the value of a `Event`
    /// instance when it represents a `.value`. The following example transforms
    /// the integer output value of a event into a string:
    ///
    ///     func getNextInteger() -> Event<Int, Error> { /* ... */ }
    ///
    ///     let integerResult = getNextInteger()
    ///     // integerResult == .value(5)
    ///     let stringResult = integerResult.map { String($0) }
    ///     // stringResult == .value("5")
    ///
    /// - Parameter transform: A closure that takes the output value of this
    ///   instance.
    /// - Returns: A `Event` instance with the result of evaluating `transform`
    ///   as the new output value if this instance represents a `.value`.
    @inlinable
    public func map<NewOutput>(_ transform: (Output) -> NewOutput) -> Event<NewOutput, Failure> {
        switch self {
        case let .value(output): return .value(transform(output))
        case let .failure(failure): return .failure(failure)
        case .finished: return .finished
        }
    }

    /// Returns a new event, mapping any failure value using the given
    /// transformation.
    ///
    /// Use this method when you need to transform the value of a `Event`
    /// instance when it represents a failure. The following example transforms
    /// the error value of a result by wrapping it in a custom `Error` type:
    ///
    ///     struct DatedError: Error {
    ///         var error: Error
    ///         var date: Date
    ///
    ///         init(_ error: Error) {
    ///             self.error = error
    ///             self.date = Date()
    ///         }
    ///     }
    ///
    ///     let result: Event<Int, Error> = // ...
    ///     // result == .failure(<error value>)
    ///     let resultWithDatedError = result.mapError { DatedError($0) }
    ///     // result == .failure(DatedError(error: <error value>, date: <date>))
    ///
    /// - Parameter transform: A closure that takes the failure value of the
    ///   instance.
    /// - Returns: A `Event` instance with the result of evaluating `transform`
    ///   as the new failure value if this instance represents a failure.
    @inlinable
    public func mapError<NewFailure>(
        _ transform: (Failure) -> NewFailure
    ) -> Event<Output, NewFailure> where NewFailure: Error {
        switch self {
        case let .value(output): return .value(output)
        case let .failure(failure): return .failure(transform(failure))
        case .finished: return .finished
        }
    }
}

// MARK: - Equatable Conformance

extension Event: Equatable where Output: Equatable, Failure: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.finished, .finished):
            return true
        case let (.failure(err1), .failure(err2)):
            return err1 == err2
        case let (.value(val1), .value(val2)):
            return val1 == val2
        default:
            return false
        }
    }
}

// MARK: - Friendly Output

extension Event: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .value(val):
            return "value(\(val))"
        case let .failure(err):
            return "failure(\(err))"
        case .finished:
            return "finished"
        }
    }
}

// MARK: - Event Convertible

/// A protocol representing `Event` convertible types
public protocol EventConvertible {
    associatedtype Output
    associatedtype Failure: Swift.Error

    var event: Event<Output, Failure> { get }
}

extension Event: EventConvertible {
    public var event: Event<Output, Failure> { self }
}
