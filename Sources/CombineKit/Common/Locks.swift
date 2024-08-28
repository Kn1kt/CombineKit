//
//  Locks.swift
//  CombineKit
//

import Foundation
import os

enum Locks {
    static var recursive: some Locking {
        return NSRecursiveLock()
    }

    static var `default`: some Locking {
        if #available(iOS 16, *) {
            return OSAllocatedUnfairLock()
        } else {
            return NSLock()
        }
    }
}

// MARK: - Locking

protocol Locking {
    /// Acquire this lock.
    func lock()
    /// Unlock this lock.
    func unlock()
}

extension Locking {
    ///  Perform a sendable closure while holding this lock.
    ///
    /// - Parameter body: A sendable closure to invoke while holding this lock.
    /// - Returns: The return value of `body`.
    /// - Throws: Anything thrown by `body`.
    ///
    public func withLock<R: Sendable>(_ body: @Sendable () throws -> R) rethrows -> R {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Default Locks

@available(iOS 16.0, *)
extension OSAllocatedUnfairLock: Locking where State == Void {}
extension NSRecursiveLock: Locking {}
extension NSLock: Locking {}
