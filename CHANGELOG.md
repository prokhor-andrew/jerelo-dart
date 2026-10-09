## 1.1.0

- Added `ContRuntime.onCancel`: `ContCancelToken.cancel()` now also runs the registered callbacks, so work that is waiting (for example on a request) can react to cancellation immediately.
- Added `ContRuntime.withCancellation`, which creates a child runtime that is cancelled with its parent or on its own.
- Fixed `Cont.bracket` never releasing its resource when the run is cancelled. `release` now runs immediately on cancel, before or during `use`, and at most once; `acquire` always runs to completion so an acquired resource is never lost.
- Fork side effects (`thenFork`, `elseFork`) now run under the parent's runtime and are cancelled together with it.
- Fixed `Cont` used through a wider value type (an upcast, an untyped `ContEitherPolicy`, or a `Never`-typed `Cont`) terminating with a `TypeError` at run time.
- Fixed `thenFork` and `elseFork` never completing when the fork builder throws. The computation now terminates with the thrown error.
- Fixed test files not being picked up by `dart test`.
- Documentation: fixed `elseTap`, `elseZip` and `abort` docs and examples, non-compiling examples and stale names; documented the `elseForkWithEnv` value-type restriction, `onCancel`, `withCancellation` and cancellation of `bracket` and forks; added a note recommending an upgrade to the latest major version.

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