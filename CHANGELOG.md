## 3.0.0
- **Breaking:** `OkPolicy.sequence`/`OkPolicy.quitFast` now return `OkPolicy<Never>`, and `CrashPolicy.sequence`/`CrashPolicy.quitFast` return `CrashPolicy<Never, Never>`. They no longer take type arguments: remove them, e.g. `OkPolicy.quitFast<String>()` becomes `OkPolicy.quitFast()`. Combinators now infer their error and value types from their continuations instead of `dynamic`.
- **Breaking:** removed `absurdify`, `thenAbsurdify` and `elseAbsurdify` from `Cont` and `ContObserver`. A `Never`-typed `Cont` can be used directly where a wider type is expected. `thenAbsurd` and `elseAbsurd` remain.
- **Breaking:** removed `ContRuntime`. `Cont.fromRun`, `runWith` and `decorate` receive the environment `E` directly: `Cont.fromRun((env, observer) { ... })`, `runWith(env, observer)` and `decorate((run, env, observer) { ... })`.
- **Breaking:** cancellation works through cancellers. The run function of `Cont.fromRun` returns a `void Function()` canceller (`() {}` for a computation that cannot be cancelled), `runWith` returns the canceller of the computation it starts, the `decorate` callback returns one, and `run` returns a `ContCancelToken` with `cancel()` and `isCancelled()`. Operators only forward a cancel to the parts that are running and to the parts that start afterwards; each `fromRun` leaf decides what cancelling means and reports it through the existing channels.
- **Breaking:** `quitFast` combinators (`both`, `either`, `all`, `any`, `coalesce`, `converge` and their instance forms) cancel the inputs still running once the result is decided.
- **Breaking:** every sum type follows one convention: a sealed base, public case classes with private constructors, created through static methods on the base, and read with `switch`.
  - `CrashOr.match` is removed. Its cases are now public, `ValueCrashOr` and `CrashCrashOr`; read them with `switch`.
  - `MergedCrash` and `CollectedCrash` have no public constructors; use `ContCrash.merge` and `ContCrash.collect`.
  - The policy case classes (`SequenceOkPolicy`, `QuitFastCrashPolicy`, …) have no public constructors; use `OkPolicy.sequence()`, `CrashPolicy.quitFast()` and the other factories.
  - `toString()` of these types uses the constructor style, e.g. `NormalCrash(error, stackTrace)`, `MergedCrash(left, right)`, `ValueCrashOr(value)`, `NextTailRec(state)`.
- The derived operators (taps, zips, forks, conditions, channel switches, loops, `*0`/`*WithEnv` variants, `withEnv` and `local0`), `Cont.bracket` and `Cont.fromDeferred` are part of jerelo.
- Added `Cont.tailRecM` and `TailRec`: a stack-safe loop that runs a step until it returns `TailRec.done(result)`; `TailRec.next(state)` continues it, and an else or crash outcome ends it.
- Added `thenUnit` and `elseUnit`, which replace the value or the error with `()`.
- Fixed `Cont` used through a wider error or value type (an upcast or a `Never`-typed `Cont`) crashing with a `TypeError` at run time. `runWith` is now an extension method with the same signature.
- Fixed `CollectedCrash` equality: `==` and `hashCode` now compare the collected crashes by value instead of by map identity.
- Fixed `MergedCrash.hashCode` ignoring the order of `left` and `right`.
- Fixed `CrashOr` equality being asymmetric across type arguments, and its hash not telling a value from a crash.
- Documentation: documented cancellation (`ContCancelToken`, cancellers returned by `fromRun`, writing cancellable leaves, how operators, `quitFast` combinators, `Cont.bracket` and forks handle a cancel); documented `Cont.tailRecM`, `TailRec`, `thenUnit` and `elseUnit`; rewrote the guide examples with core operators, including a `retry` helper built on `Cont.tailRecM`; fixed stale names in doc comments, environment injection examples and the `retryWithBackoff` guide helper; removed the `absurdify` family; described combinator policies by their own channel and exits (including `CrashPolicy.quitFast`, `shouldFavorCrash`, empty lists and `runAll` completion order), crash types, observer guarantees, the `onPanic` default and `fromRun` catching; added a note against upcasting the environment type.

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