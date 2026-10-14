## 1.1.0

- Fixed long chains of synchronous steps overflowing the stack (from about 500 steps): the outcome was lost, or an uncaught "Stack Overflow" was thrown. `thenDo`, `elseDo`, `Cont.fromDeferred`, `local` and everything built on them now run in a loop with constant stack space, so chains built in a loop, with `fold` or by recursion can have any number of steps. Long chains also run several times faster.
- Changed: when a `Cont.fromRun` leaf reports while its run function is still running, the next stage now starts after the run function returns, so code after the report runs first. Before, the next stage ran inside the report call. Leaves that report as their last instruction, as documented, behave the same.
- Documentation: added a Stack Safety section to the execution reference, and described when the next stage starts after a leaf reports.

## 1.0.4

- Fixed `Cont` used through a wider value type (an upcast, an untyped `ContEitherPolicy`, or a `Never`-typed `Cont`) terminating with a `TypeError` at run time.
- Fixed `thenFork` and `elseFork` never completing when the fork builder throws. The computation now terminates with the thrown error.
- Fixed test files not being picked up by `dart test`.
- Documentation: fixed `elseTap`, `elseZip` and `abort` docs and examples, non-compiling examples and stale names; documented the `elseForkWithEnv` value-type restriction; added a note recommending an upgrade to the latest major version; documented the limits of cooperative cancellation, including when `bracket` does not release its resource; documented `mergeWhenAll` waiting for every input and its completion order, how forks, `ff` and `fromRun` behave, and that a computation delivers at most one result; fixed untyped examples; added a note against upcasting the environment type.

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