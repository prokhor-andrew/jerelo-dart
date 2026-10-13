## 3.0.0
- **Breaking:** `OkPolicy.sequence`/`OkPolicy.quitFast` now return `OkPolicy<Never>`, and `CrashPolicy.sequence`/`CrashPolicy.quitFast` return `CrashPolicy<Never, Never>`. They no longer take type arguments: remove them, e.g. `OkPolicy.quitFast<String>()` becomes `OkPolicy.quitFast()`. Combinators now infer their error and value types from their continuations instead of `dynamic`.
- **Breaking:** removed `absurdify`, `thenAbsurdify` and `elseAbsurdify` from `Cont` and `ContObserver`. A `Never`-typed `Cont` can be used directly where a wider type is expected. `thenAbsurd` and `elseAbsurd` remain.
- **Breaking:** removed cancellation from core. `ContCancelToken`, `ContRuntime.isCancelled` and `ContRuntime.extendCancellation` are gone, `run` returns `void`, and `ContRuntime` only carries the environment (`env` and `copyUpdateEnv`). `quitFast` combinators return as soon as the result is decided; the losing inputs keep running and their results are ignored. A cancellable `Cont` will be a separate feature.
- **Breaking:** every sum type follows one convention: a sealed base, public case classes with private constructors, created through static methods on the base, and read with `switch`.
  - `CrashOr.match` is removed. Its cases are now public, `ValueCrashOr` and `CrashCrashOr`; read them with `switch`.
  - `MergedCrash` and `CollectedCrash` have no public constructors; use `ContCrash.merge` and `ContCrash.collect`.
  - The policy case classes (`SequenceOkPolicy`, `QuitFastCrashPolicy`, …) have no public constructors; use `OkPolicy.sequence()`, `CrashPolicy.quitFast()` and the other factories.
  - `toString()` of these types uses the constructor style, e.g. `NormalCrash(error, stackTrace)`, `MergedCrash(left, right)`, `ValueCrashOr(value)`, `NextTailRec(state)`.
- Added `Cont.tailRecM` and `TailRec`: a stack-safe loop that runs a step until it returns `TailRec.done(result)`; `TailRec.next(state)` continues it, and an else or crash outcome ends it.
- Added `thenUnit` and `elseUnit`, which replace the value or the error with `()`.
- Fixed `Cont` used through a wider error or value type (an upcast or a `Never`-typed `Cont`) crashing with a `TypeError` at run time. `runWith` is now an extension method with the same signature.
- Fixed `CollectedCrash` equality: `==` and `hashCode` now compare the collected crashes by value instead of by map identity.
- Fixed `MergedCrash.hashCode` ignoring the order of `left` and `right`.
- Fixed `CrashOr` equality being asymmetric across type arguments, and its hash not telling a value from a crash.
- Documentation: removed cancellation; documented `Cont.tailRecM`, `TailRec`, `thenUnit` and `elseUnit`; rewrote the guide examples with core operators, including a `retry` helper built on `Cont.tailRecM`; fixed stale names in doc comments, environment injection examples and the `retryWithBackoff` guide helper; removed the `absurdify` family; described combinator policies by their own channel and exits (including `CrashPolicy.quitFast`, `shouldFavorCrash`, empty lists and `runAll` completion order), crash types, observer guarantees, the `onPanic` default and `fromRun` catching; added a note against upcasting the environment type.

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