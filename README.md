# 🦿CombineKit
**CombineKit** is an open-source package of operators, publishers and schedulers for Combine framework.

This package has three main goals:

- Achieve first-class integration with Combine
- Offer a comprehensive suite of common reactive framework operators
- Ensure thread safety and eliminate memory leaks

## Motivation

This package is inspired by [CombineExt](https://github.com/CombineCommunity/CombineExt), and many implementations strongly based on this project, but came with thread-safety support in mind and elaborately followed Combine contracts.

The main goal of this package is to extend and improve behavior of default operators. In [Contents](#Contents) section described concrete problems with operators, publishers and schedulers and provided detailed description how this version improves its work.

## Contents

#### Operators

- [`withLatestFrom(_:resultSelector:)`](#WithLatestFrom): Merges up to four publishers into a single publisher by combining each value from self with the latest value from the other publishers, if any.
  - Added serialization to access to latest value
  - Added serialization to subscribe on upstream
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

- [`retryWhen(_:)`](#RetryWhen): Repeats the source publisher on error when the notifier emits a next value. If the source publisher errors and the notifier completes, it will complete the source sequence.
  - Resolved [double subscription issue](https://github.com/CombineCommunity/CombineExt/issues/148)
  - Resolved [resubscribe on upstream issue](https://github.com/CombineCommunity/CombineExt/pull/151)
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

- [`discardableSubscribe(on:options:)`](#DiscardableSubscribeOn): An efficient version of `subscribe(on:options:)` with optimized `cancel()` and `request(_:)`.
  - Resolved race conditions on `receive(subscription:)`
  - Resolved memory leaks on `cancel()`
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

- [`prefix(while:behavior:)`](#InclusivePrefixWhile): An overload on `Publisher.prefix(while:)` that allows for inclusion of the first element that doesn’t pass the `while` predicate.
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

- [`materialize()`](#Materialize): Converts any publisher to a publisher of its events.
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

- [`dematerialize()`](#Dematerialize): Converts any previously-materialized publisher into its original form.
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

#### Publishers

- [`AnyPublisher.create(_:)`](#Publishers.Create): Create a publisher which accepts a closure with a subscriber argument, to which you can dynamically send value or completion events.
  - Added thread-safe conformance to `Subscription` with serialized `request(_:)` and `cancel()`

- [`AnyCurrentValuePublisher`](#AnyCurrentValuePublisher): A publisher that performs type erasure by wrapping another `CurrentValuePublisher`.

#### Schedulers
- [`UIScheduler`](#UIScheduler): A scheduler that executes its work on the main queue immediately, if scheduled from main.

- [`MainScheduler`](#MainScheduler): A scheduler that executes its work on the main queue as soon as possible, preserving the order between actions.
  - Improved `receive(subscriber:)` with no additional thread hops, comparing to the two in `DispatchQueue.main` scheduler
  - Optimized recursive calls which will be executed immediately and will not cause a thread hop

## Adding CombineKit as a Dependency

### Swift Package Manager

Add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: “https://github.com/Kn1kt/CombineKit.git”, from: “1.0.0”),
```

### CocoaPods

Add the following line to your **Podfile**:

```rb
pod 'CombineKit'
```

Finally, add `import CombineKit` to your source code.

## Operators

This section outlines several custom operators `CombineKit` provides.

### WithLatestFrom

Merges up to four publishers into a single publisher by combining each value from `self` with the _latest_ value from the other publishers, if any.

```swift
let taps = PassthroughSubject<Void, Never>()
let values = CurrentValueSubject<String, Never>(“Hello”)

taps
  .withLatestFrom(values)
  .sink(receiveValue: { print(“withLatestFrom: \($0)”) })

taps.send()
taps.send()
values.send(“World!”)
taps.send()
```

#### Output:

```none
withLatestFrom: Hello
withLatestFrom: Hello
withLatestFrom: World!
```

### RetryWhen

Repeats the source publisher on error when the notifier emits a next value. If the source publisher errors and the notifier completes, it will complete the source sequence.

```swift
var times = 0
        
Deferred {
  defer { times += 1 }
  return times > 0
    ? Just(1).setFailureType(to: SomeError.self).eraseToAnyPublisher()
    : Fail<Int, SomeError>(error: SomeError(code: 404)).eraseToAnyPublisher()
}
.retryWhen { errorPublisher in
  errorPublisher
    .flatMap { error in
      return error.code == 404
        ? Just(error).eraseToAnyPublisher()
        : Empty().eraseToAnyPublisher()
    }
}
.sink(
    receiveCompletion: { print("retryWhen: \($0)") },
    receiveValue: { print("retryWhen: \($0)") }
)
```

#### Output:

```none
retryWhen: 1
retryWhen: finished
```

### DiscardableSubscribeOn

An efficient version of `subscribe(on:options:)` with optimized `cancel()` and `request(_:)`, eliminating race conditions on `receive(subscription:)`.

In contrast with `receive(on:options:)`, which affects downstream messages, `subscribe(on:options:)` changes the execution context of upstream messages.

In the following example, the `subscribe(on:options:)` operator causes `ioPerformingPublisher` to receive requests on `backgroundQueue`, while the `receive(on:options:)` causes `uiUpdatingSubscriber` to receive elements and completion on `RunLoop.main`.

Using `subscribe(on:options:)` also causes the upstream publisher to perform `cancel()` using the specified scheduler.

```swift
let ioPerformingPublisher == // Some publisher.
let uiUpdatingSubscriber == // Some subscriber that updates the UI.

ioPerformingPublisher
   .subscribe(on: backgroundQueue)
   .receive(on: RunLoop.main)
   .subscribe(uiUpdatingSubscriber)
```

### InclusivePrefixWhile

An overload on `Publisher.prefix(while:)` that allows for inclusion of the first element that doesn’t pass the `while` predicate.

```swift
let subject = PassthroughSubject<Int, Never>()

subject
  .prefix(
    while: { $0 % 2 == 0 },
    behavior: .inclusive
  )
  .sink(
    receivecompletion: { print("prefix: \($0)") },
    receiveValue: { print("prefix: \($0)") }
  )
  
subject.send(0)
subject.send(2)
subject.send(4)
subject.send(5)
```

#### Output:

```none
prefix: 0
prefix: 2
prefix: 4
prefix: 5
prefix: finished
```

### Materialize

Converts any publisher to a publisher of its events.

```swift
let subject = PassthroughSubject<Int, SomeError>()

subscription = subject
  .materialize()
  .sink(
    receiveCompletion: { print("materialize: \($0)") },
    receiveValue: { print("materialize: \($0)") }
  )

subject.send(1)
subject.send(completion: .failure(SomeError()))
```

#### Output:

```none
materialize: value(1)
materialize: failure(SomeError())
materialize: finished
```

### Dematerialize

Converts any previously-materialized publisher into its original form.

```swift
let subject = PassthroughSubject<Int, SomeError>()

subscription = subject
  .materialize()
  .dematerialize()
  .sink(
    receiveCompletion: { print("dematerialize: \($0)") },
    receiveValue: { print("dematerialize: \($0)") }
  )

subject.send(1)
subject.send(completion: .failure(SomeError)
```

#### Output:

```none
dematerialize: 1
dematerialize: failure(SomeError)
```

## Publishers

This section outlines most used custom publishers `CombineKit` provides.

### Publishers.Create

Create a publisher which accepts a closure with a subscriber argument, to which you can dynamically send value or completion events.

This lets you easily create custom publishers to wrap any non-publisher asynchronous work, while still respecting the downstream consumer's backpressure demand.

You should return a `Cancellable`-conforming object from the closure in which you can define any cleanup actions to execute when the publisher completes or the subscription to the publisher is canceled.

```swift
AnyPublisher<String, MyError>.create { subscriber in
  // Values
  subscriber.send("Hello")
  subscriber.send("World!")

  // Complete with error
  subscriber.send(completion: .failure(SomeError()))

  // Or, complete successfully
  subscriber.send(completion: .finished)

  return AnyCancellable {
    // Perform clean-up
  }
}
```

You can also use an `AnyPublisher` initializer with the same signature:

```swift
AnyPublisher<String, MyError> { subscriber in 
  /// ...
  return AnyCancellable { }
```

### AnyCurrentValuePublisher

A publisher that performs type erasure by wrapping another `CurrentValuePublisher`. This wrapper allows to hide `Subject` related methods from caller.

- **Note**: The extension to `CurrentValueSubject` also provided.

## Schedulers

This section outlines UI specific schedulers `CombineKit` provides.

### UIScheduler

A scheduler that executes its work on the main queue immediately, if scheduled from main

If `UIScheduler.schedule` is invoked from the main thread then the unit of work will be performed immediately. This is in contrast to `MainScheduler.schedule`, which can incur a thread hop before executing, since it guarantees event ordering.

This scheduler can be useful for situations where you need work executed as quickly as possible on the main thread, and for which a thread hop would be problematic, such as when performing animations.

- **Important**: The order between actions may not be preserved, if this is matter, use `MainScheduler` instead.

### MainScheduler

A scheduler that executes its work on the main queue as soon as possible.

If `MainScheduler.schedule` is invoked from the main thread then the unit of work may be performed immediately.

This scheduler can be useful for situations where you need work executed as quickly as possible on the main thread, and for which a thread hop would be problematic, such as when updating UI.

- **Important**: The order between actions will always be preserved, except for recursive calls which will be executed immediately and will not cause a thread hop.

## CombineExt License

Copyright (c) 2020 Combine Community, and/or Shai Mishali

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
