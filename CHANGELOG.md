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