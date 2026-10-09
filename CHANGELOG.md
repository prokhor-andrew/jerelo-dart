## 3.0.0
- **Breaking:** `OkPolicy.sequence`/`OkPolicy.quitFast` now return `OkPolicy<Never>`, and `CrashPolicy.sequence`/`CrashPolicy.quitFast` return `CrashPolicy<Never, Never>`. They no longer take type arguments: remove them, e.g. `OkPolicy.quitFast<String>()` becomes `OkPolicy.quitFast()`. Combinators now infer their error and value types from their continuations instead of `dynamic`.
- **Breaking:** removed `absurdify`, `thenAbsurdify` and `elseAbsurdify` from `Cont` and `ContObserver`. A `Never`-typed `Cont` can be used directly where a wider type is expected. `thenAbsurd` and `elseAbsurd` remain.
- **Breaking:** removed `ContRuntime.extendCancellation`. Use `ContRuntime.withCancellation` and call `cancel`.
- Added `ContRuntime.onCancel`: `ContCancelToken.cancel()` now also runs the registered callbacks, so work that is waiting (for example on a request) can react to cancellation immediately.
- Added `ContRuntime.withCancellation`, which creates a child runtime that is cancelled with its parent or on its own.
- Fixed `Cont` used through a wider error or value type (an upcast or a `Never`-typed `Cont`) crashing with a `TypeError` at run time. `runWith` is now an extension method with the same signature.
- Fixed operators delivering results after the run was cancelled. No result reaches `run`'s callbacks after `cancel()`, on any channel.
- Fixed `Cont.bracket` not releasing its resource when the run is cancelled while `use` runs. `release` now runs immediately on cancel and at most once; `acquire` always runs to completion so an acquired resource is never lost.
- Fixed `CollectedCrash` equality: `==` and `hashCode` now compare the collected crashes by value instead of by map identity.
- Fixed `MergedCrash.hashCode` ignoring the order of `left` and `right`.
- Fork side effects (`thenFork`, `elseFork`, `crashFork`) now run under the parent's runtime and are cancelled together with it.
- Documentation: fixed `elseTap` and `elseUnless` docs and examples, stale names in doc comments, environment injection examples and the `retryWithBackoff` guide helper; removed the `absurdify` family; documented `onCancel`, `withCancellation` and cancellation of `bracket` and forks.

## 2.0.0
- Split previous Else channel into Crash and Else channels
- Added new operators for Else and Crash channels
- Renamed `decor` into `decorate`
- Replaced `elseIf` with `elseUnless`
- Reworked combination operators and their policies
- Renamed `recover` and `abort` operators to `demote` and `promote`
- Removed `trap` as it was not core operator, but rather an extension
- Replaced `askThen`'s logic with `ask`'s one. 
- Added `askElse` operator
- Renamed `injectInto` into `thenInject`
- Added `elseInject` operator
- Renamed `injectedBy` into `injectedByThen`
- Added `injectedByElse` operator
- Renamed `scope` into `withEnv`
- Bug fixes, improvements, performance improvements

## 1.0.3

- Fixed `trap` function interface. 
- Decreased min dart version requirement.

## 1.0.2

- Reduced published package size (excluded `test/` and extra documentation from release bundle).

## 1.0.1

- Renamed `forever` into `thenForever`
- Added `elseForever` method
- Added `Cont.askThen` static method
- Added example