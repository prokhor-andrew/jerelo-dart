[Home](../../README.md) > API Reference > Types

# Types

Core types used throughout the Jerelo continuation library.

---

## Table of Contents

- [ContCrash](#contcrash)
  - [NormalCrash](#normalcrash)
  - [MergedCrash](#mergedcrash)
  - [CollectedCrash](#collectedcrash)
- [CrashOr](#crashor)
  - [ValueCrashOr](#valuecrashor)
  - [CrashCrashOr](#crashcrashor)
- [BracketOutcome](#bracketoutcome)
  - [ThenBracketOutcome](#thenbracketoutcome)
  - [ElseBracketOutcome](#elsebracketoutcome)
  - [CrashBracketOutcome](#crashbracketoutcome)
- [ContCancelToken](#contcanceltoken)
- [ContObserver](#contobserver)
  - [SafeObserver](#safeobserver)

---

## ContCrash

```dart
sealed class ContCrash
```

Represents unexpected exceptions (crashes) that occur during continuation execution.

Unlike typed errors on the else channel (type `F`), crashes represent unexpected failures — exceptions that were not part of the expected control flow. They can still be recovered from with the crash channel operators. `ContCrash` is a sealed class with three subtypes representing different crash scenarios.

**Static Methods:**

```dart
static ContCrash merge(ContCrash left, ContCrash right)
```
Combines two crashes into a `MergedCrash`.

- **Parameters:**
  - `left`: The first crash
  - `right`: The second crash

```dart
static ContCrash collect(Map<int, ContCrash> crashes)
```
Combines multiple crashes from a list operation into a `CollectedCrash`. The crash keeps its own unmodifiable copy of `crashes`, so changing the map afterwards does not affect it.

- **Parameters:**
  - `crashes`: A map from index to crash

```dart
static CrashOr<T> tryCatch<T>(T Function() function)
```
Executes a function and captures any thrown exception as a `CrashOr`.

- **Parameters:**
  - `function`: The function to execute

- **Returns:** A `CrashOr<T>` containing either the function's return value or a `NormalCrash`

**Example:**
```dart
final result = ContCrash.tryCatch(() => int.parse('not a number'));
switch (result) {
  case ValueCrashOr(value: final value):
    print('Parsed: $value');
  case CrashCrashOr(crash: final crash):
    print('Failed: ${crash.error}');
}
```

---

### NormalCrash

```dart
final class NormalCrash extends ContCrash
```

A single exception with its stack trace. It has no public constructor; it is created when an exception is caught, for example by `ContCrash.tryCatch`.

**Fields:**
- `error: Object` — The exception that was thrown
- `stackTrace: StackTrace` — The stack trace captured at the point of the exception

---

### MergedCrash

```dart
final class MergedCrash extends ContCrash
```

Two crashes combined from a two-way operation (e.g., `coalesce`, `crashZip`, or `both`/`either` with `runAll`).

**Fields:**
- `left: ContCrash` — The crash from the left continuation
- `right: ContCrash` — The crash from the right continuation

It has no public constructor; create one with `ContCrash.merge`.

---

### CollectedCrash

```dart
final class CollectedCrash extends ContCrash
```

Multiple crashes from a list operation, indexed by position. It is produced by:
- `converge` with any policy, when every input crashes; an empty `converge` gives an empty `CollectedCrash`
- `all` and `any` with `runAll`, whenever a crash is reported, even if only one input crashed

**Fields:**
- `crashes: Map<int, ContCrash>` — An unmodifiable map from the index in the original list to the crash

It has no public constructor; create one with `ContCrash.collect`.

---

## CrashOr

```dart
sealed class CrashOr<T>
```

A result type representing either a value or a crash. Returned by `ContCrash.tryCatch`. Read it with `switch`:

```dart
final result = ContCrash.tryCatch(() => riskyOperation());
final output = switch (result) {
  ValueCrashOr(value: final value) => 'Got: $value',
  CrashCrashOr(crash: final crash) => 'Crashed: ${crash.error}',
};
```

Results compare by value: two `ValueCrashOr`s are equal when their values are equal, and two `CrashCrashOr`s when their crashes are equal; a value never equals a crash.

### ValueCrashOr

```dart
final class ValueCrashOr<T> extends CrashOr<T>
```

The function returned normally. It has no public constructor; it is created by `ContCrash.tryCatch`.

**Fields:**
- `value: T` — The value the function returned

### CrashCrashOr

```dart
final class CrashCrashOr<T> extends CrashOr<T>
```

The function threw. It has no public constructor; it is created by `ContCrash.tryCatch`.

**Fields:**
- `crash: NormalCrash` — The captured exception and stack trace

---

## BracketOutcome

```dart
sealed class BracketOutcome<F, A>
```

How the `use` of a [Cont.bracket](construction.md#contbracket) ended. `release` receives it next to the resource. Read it with `switch`:

```dart
release: (tx, outcome) => switch (outcome) {
  ThenBracketOutcome() => commit(tx),
  ElseBracketOutcome() || CrashBracketOutcome() => rollback(tx),
},
```

It has no public constructor; `Cont.bracket` creates it. To get a particular case in a test, run a `bracket` whose `use` produces it: `Cont.of(value)`, `Cont.error(error)` or a crash.

Outcomes compare by value, and a case never equals another case.

### ThenBracketOutcome

```dart
final class ThenBracketOutcome<F, A> extends BracketOutcome<F, A>
```

`use` succeeded.

**Fields:**
- `value: A` — The value `use` succeeded with

### ElseBracketOutcome

```dart
final class ElseBracketOutcome<F, A> extends BracketOutcome<F, A>
```

`use` failed with a business-logic error. A cancel that `use` reports through the else channel arrives as this case.

**Fields:**
- `error: F` — The error `use` failed with

### CrashBracketOutcome

```dart
final class CrashBracketOutcome<F, A> extends BracketOutcome<F, A>
```

`use` crashed, or threw while its continuation was being built.

**Fields:**
- `crash: ContCrash` — The crash `use` ended with

---

## ContCancelToken

```dart
final class ContCancelToken
```

Cancels a running continuation.

Returned by `run`. It has a private constructor. Calling `cancel` forwards the cancellation to the parts of the computation that are running, and to the parts that start afterwards. Each part decides what cancelling means and how to report it: a part started with `Cont.fromRun` runs the canceller its run function returned. See [Cancellation](execution.md#cancellation).

**Methods:**

```dart
void cancel()
```
Cancels the computation. Only the first call has an effect.

```dart
bool isCancelled()
```
Returns `true` if `cancel` has been called on this token. It does not tell whether the computation has stopped: the computation reports how it ended through the callbacks passed to `run`.

---

## ContObserver

```dart
sealed class ContObserver<F, A>
```

An observer that handles all three outcome channels of a continuation: crash, error, and success.

`ContObserver` provides the callback mechanism for receiving results from a `Cont` execution. It encapsulates handlers for crashes (unexpected exceptions), errors (typed business failures), and successful values.

`ContObserver` is sealed, so instances cannot be created directly. Instead, new observers are derived from existing ones using the copy methods. The initial observer is provided by the library when a continuation is executed (e.g., inside `Cont.fromRun` or `decorate`).

**Fields:**

```dart
final void Function(ContCrash crash) onCrash
```
The callback invoked when the continuation crashes with an unexpected exception.

```dart
final void Function(F error) onElse
```
The callback invoked when the continuation terminates with a typed error.

```dart
final void Function(A value) onThen
```
The callback invoked when the continuation produces a successful value.

**Methods:**

```dart
ContObserver<F, A> copyUpdateOnCrash(
  void Function(ContCrash crash) onCrash,
)
```
Creates a new observer with an updated crash handler.

- **Parameters:**
  - `onCrash`: The new crash handler to use

```dart
ContObserver<F2, A> copyUpdateOnElse<F2>(
  void Function(F2 error) onElse,
)
```
Creates a new observer with an updated error handler and potentially different error type.

- **Parameters:**
  - `onElse`: The new error handler to use

```dart
ContObserver<F, A2> copyUpdateOnThen<A2>(
  void Function(A2 value) onThen,
)
```
Creates a new observer with an updated value handler and potentially different value type.

- **Parameters:**
  - `onThen`: The new value handler to use

```dart
ContObserver<F2, A2> copyUpdate<F2, A2>({
  required void Function(ContCrash crash) onCrash,
  required void Function(F2 error) onElse,
  required void Function(A2 value) onThen,
})
```
Creates a new observer with all three handlers replaced.

- **Parameters:**
  - `onCrash`: The new crash handler
  - `onElse`: The new error handler
  - `onThen`: The new value handler

**Extension Methods:**

The following extension methods widen a `Never`-typed channel to an arbitrary type. When an observer's success or error type is `Never` (meaning that channel can never fire), these methods replace the unreachable callback with a no-op. Use them instead of upcasting the observer: reading the `Never`-typed callback through a wider type (for example `onThen` of a `ContObserver<F, Never>` used as a `ContObserver<F, int>`) fails at run time with a `TypeError`.

```dart
// On ContObserver<F, Never>:
ContObserver<F, A> thenAbsurd<A>()
```
Returns a copy of this observer with the success type widened to `A`. Because the original success type is `Never`, the `onThen` callback can never be reached, so it is replaced with a no-op.

```dart
// On ContObserver<Never, A>:
ContObserver<F, A> elseAbsurd<F>()
```
Returns a copy of this observer with the error type widened to `F`. Because the original error type is `Never`, the `onElse` callback can never be reached, so it is replaced with a no-op.

---

### SafeObserver

```dart
final class SafeObserver<F, A> extends ContObserver<F, A>
```

An observer that tracks whether any callback has already been invoked, preventing duplicate invocations.

Used by `Cont.fromRun` to wrap user-provided callbacks with idempotence and exception safety. Only the observer handed to the `fromRun` run function is guarded: observers derived from it with `copyUpdate*` share its `isUsed`, but their new callbacks run every time they are called.

**Fields:**
- `isUsed: bool Function()` — Returns `true` if any callback on this observer has already been invoked
