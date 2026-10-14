## 2.2.0
- Fixed long chains of synchronous steps overflowing the stack (from about 500 steps): the outcome was lost, or an uncaught "Stack Overflow" was thrown. `thenDo`, `elseDo`, `crashDo`, `Cont.fromDeferred`, `local` and everything built on them now run in a loop with constant stack space, so chains built in a loop, with `fold` or by recursion can have any number of steps. Long chains also run several times faster.
- Changed: when a `Cont.fromRun` leaf reports while its run function is still running, the next stage now starts after the run function returns, so code after the report runs first. Before, the next stage ran inside the report call. Leaves that report as their last instruction, as documented, behave the same.
- Documentation: added a Stack Safety section to the execution reference, and described when the next stage starts after a leaf reports.

## 2.1.0
- Fixed `Cont` used through a wider error or value type (an upcast, an untyped policy, or a `Never`-typed `Cont`) crashing with a `TypeError` at run time. `runWith` is now an extension method with the same signature.
- Fixed `CollectedCrash` equality: `==` and `hashCode` now compare the collected crashes by value instead of by map identity.
- Fixed `MergedCrash.hashCode` ignoring the order of `left` and `right`.
- Deprecated `absurdify`, `thenAbsurdify` and `elseAbsurdify` on `Cont` and `ContObserver`. They are no longer needed and will be removed in 3.0.0. `thenAbsurd` and `elseAbsurd` are not affected.
- Documentation: fixed `elseTap` and `elseUnless` docs and examples, stale names in doc comments, environment injection examples, untyped combinator examples and the `retryWithBackoff` guide helper; added a note recommending an upgrade to the latest major version; documented the limits of cooperative cancellation, including when `bracket` does not release its resource; described combinator policies by their own channel and exits (including `CrashPolicy.quitFast`, `shouldFavorCrash`, empty lists and `runAll` completion order), crash types, fork ordering, observer guarantees, the `onPanic` default and `fromRun` catching; made the `retry` guide helper stack safe; added a note against upcasting the environment type.

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