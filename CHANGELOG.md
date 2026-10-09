## 2.1.0
- Added `ContRuntime.onCancel`: `ContCancelToken.cancel()` now also runs the registered callbacks, so work that is waiting (for example on a request) can react to cancellation immediately.
- Added `ContRuntime.withCancellation`, which creates a child runtime that is cancelled with its parent or on its own. Deprecated `ContRuntime.extendCancellation`: a predicate cannot notify, so work such as `Cont.bracket` was not cleaned up when it became true. It will be removed in 3.0.0.
- Fixed operators delivering results after the run was cancelled. No result reaches `run`'s callbacks after `cancel()`, on any channel.
- Fixed `Cont.bracket` not releasing its resource when the run is cancelled while `use` runs. `release` now runs immediately on cancel and at most once; `acquire` always runs to completion so an acquired resource is never lost.
- Fork side effects (`thenFork`, `elseFork`, `crashFork`) now run under the parent's runtime and are cancelled together with it.
- Fixed `Cont` used through a wider error or value type (an upcast, an untyped policy, or a `Never`-typed `Cont`) crashing with a `TypeError` at run time. `runWith` is now an extension method with the same signature.
- Fixed `CollectedCrash` equality: `==` and `hashCode` now compare the collected crashes by value instead of by map identity.
- Fixed `MergedCrash.hashCode` ignoring the order of `left` and `right`.
- Deprecated `absurdify`, `thenAbsurdify` and `elseAbsurdify` on `Cont` and `ContObserver`. They are no longer needed and will be removed in 3.0.0. `thenAbsurd` and `elseAbsurd` are not affected.
- Documentation: fixed `elseTap` and `elseUnless` docs and examples, stale names in doc comments, environment injection examples, untyped combinator examples and the `retryWithBackoff` guide helper; documented `onCancel`, `withCancellation` and cancellation of `bracket` and forks; added a note recommending an upgrade to the latest major version; described combinator policies by their own channel and exits (including `CrashPolicy.quitFast`, `shouldFavorCrash`, empty lists and `runAll` completion order), crash types, fork ordering, observer guarantees, the `onPanic` default and `fromRun` catching; made the `retry` guide helper stack safe; added a note against upcasting the environment type.

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