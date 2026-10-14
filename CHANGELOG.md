## 3.0.0
- **Breaking:** `OkPolicy.sequence`/`OkPolicy.quitFast` now return `OkPolicy<Never>`, and `CrashPolicy.sequence`/`CrashPolicy.quitFast` return `CrashPolicy<Never, Never>`. They no longer take type arguments: remove them, e.g. `OkPolicy.quitFast<String>()` becomes `OkPolicy.quitFast()`. Combinators now infer their error and value types from their continuations instead of `dynamic`.
- **Breaking:** removed `absurdify`, `thenAbsurdify` and `elseAbsurdify` from `Cont` and `ContObserver`. A `Never`-typed `Cont` can be used directly where a wider type is expected. `thenAbsurd` and `elseAbsurd` remain.
- **Breaking:** removed `ContRuntime`. `Cont.fromRun`, `runWith` and `decorate` receive the environment `E` directly: `Cont.fromRun((env, observer) { ... })`, `runWith(env, observer)` and `decorate((run, env, observer) { ... })`.
- **Breaking:** cancellation works through cancellers instead of polling `ContRuntime.isCancelled`. The run function of `Cont.fromRun` returns a `void Function()` canceller (`() {}` for a computation that cannot be cancelled), `runWith` returns the canceller of the computation it starts, and the `decorate` callback returns one. `run` still returns a `ContCancelToken`: `cancel()` now runs the cancellers, and `isCancelled()` only tells that `cancel()` was called. Operators only forward a cancel to the parts that are running and to the parts that start afterwards; each `fromRun` leaf decides what cancelling means and reports it through the existing channels, so a cancelled computation no longer stops silently.
- **Breaking:** `quitFast` combinators (`both`, `either`, `all`, `any`, `coalesce`, `converge` and their instance forms) cancel the inputs still running through their cancellers once the result is decided.
- **Breaking:** `Cont.bracket` forwards a cancel to `use` only and runs `release` once `use` reports back, on any channel; `acquire` and `release` are never cancelled. A cancel no longer releases the resource on its own.
- **Breaking:** every sum type follows one convention: a sealed base, public case classes with private constructors, created through static methods on the base, and read with `switch`.
  - `CrashOr.match` is removed. Its cases are now public, `ValueCrashOr` and `CrashCrashOr`; read them with `switch`.
  - `MergedCrash` and `CollectedCrash` have no public constructors; use `ContCrash.merge` and `ContCrash.collect`.
  - The policy case classes (`SequenceOkPolicy`, `QuitFastCrashPolicy`, …) have no public constructors; use `OkPolicy.sequence()`, `CrashPolicy.quitFast()` and the other factories.
  - `toString()` of these types uses the constructor style, e.g. `NormalCrash(error, stackTrace)`, `MergedCrash(left, right)`, `ValueCrashOr(value)`.
- **Breaking:** removed `thenForever`, `elseForever` and `crashForever`. Since a cancel now ends a loop, they could end on their own channel, which their `Never` types ruled out. Use a predicate that is always true instead: `thenWhile((_) => true)`, `elseWhile((_) => true)`, `crashWhile((_) => true)`.
- The derived operators (taps, zips, forks, conditions, channel switches, loops, `*0`/`*WithEnv` variants, `withEnv` and `local0`), `Cont.bracket` and `Cont.fromDeferred` are part of jerelo.
- Added `thenUnit` and `elseUnit`, which replace the value or the error with `()`.
- Fixed `Cont` used through a wider error or value type (an upcast or a `Never`-typed `Cont`) crashing with a `TypeError` at run time. `runWith` is now an extension method (`ContRunWithExtension`).
- Fixed `CollectedCrash` equality: `==` and `hashCode` now compare the collected crashes by value instead of by map identity.
- Fixed `MergedCrash.hashCode` ignoring the order of `left` and `right`.
- Fixed `CrashOr` equality being asymmetric across type arguments, and its hash not telling a value from a crash.
- Fixed `all`, `any` and `converge` with a `runAll` policy reporting a throwing `combine` inconsistently: depending on which input finished last, the throw became a crash of one input in a `CollectedCrash`, a plain crash, or was ignored and its input's outcome dropped. A throwing `combine` is now always a crash of the combinator: once every input has finished, the result is that `NormalCrash`, as with `both`, `either` and `coalesce`.
- Fixed `both` and `either` with a `runAll` policy reporting an input that throws while starting at once, skipping the policy. Such a throw is now that input's crash: the combinator waits for the other input, follows `shouldFavorCrash`, and merges two crashes into a `MergedCrash`, as `all` and `coalesce` already did.
- Fixed `all` and `any` with a `quitFast` policy returning a fixed-length list, on which `add` threw. They now return a growable list, like the other policies.
- Fixed `ContCrash.collect` keeping the caller's map: changing it afterwards changed the crash, including its `==` and `hashCode`. A `CollectedCrash` now keeps its own copy, and `crashes` is unmodifiable.
- Fixed `quitFast` combinators starting the remaining inputs after an earlier input had already decided the result synchronously; those inputs ran their start code, such as sending a request, only to be cancelled at once. Inputs are no longer started once the result is decided.
- Fixed a throwing `onPanic` losing the panic it was handling: the zone received `onPanic`'s own error. The original panic is now rethrown in a microtask.
- Fixed `Cont.bracket` sending a throwing `onReleasePanic` to the main computation's `onPanic`, losing the release error. The release error is now rethrown in a microtask, as with a throwing `onPanic`.
- Fixed a retry loop freezing inside `cancel()`. When an attempt reported the cancel through `onElse`, as the docs recommend, `elseWhile` treated it as one more failure and started another attempt, which was cancelled at once and reported again; with an always-true predicate this never ended. After a cancel, loops (`thenWhile`, `elseWhile`, `crashWhile` and the `until` forms) now start no new iteration: they end with the outcome of the iteration that was running, without calling the predicate.
- Fixed a throw after a computation already reported its outcome being silently dropped. In the run function of `Cont.fromRun`, and in `thenDo`, `elseDo`, `crashDo` and `Cont.bracket`, such a throw now goes to `onPanic`, and the outcome already reported stands; a throw before the outcome is still a crash. This matches the canceller, which already worked this way.
- Documentation: documented cancellation (`ContCancelToken`, cancellers returned by `fromRun`, writing cancellable leaves, how operators, `quitFast` combinators, `Cont.bracket` and forks handle a cancel); documented `thenUnit` and `elseUnit`; rewrote the guide examples with core operators, including a `retry` helper built on `elseWhile`; fixed stale names in doc comments, environment injection examples and the `retryWithBackoff` guide helper; removed the `absurdify` family; described combinator policies by their own channel and exits (including `CrashPolicy.quitFast`, `shouldFavorCrash`, empty lists and `runAll` completion order), crash types, observer guarantees, the `onPanic` default and `fromRun` catching; added a note against upcasting the environment type.

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