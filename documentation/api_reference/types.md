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
- [ContRuntime](#contruntime)
- [ContObserver](#contobserver)
  - [SafeObserver](#safeobserver)
- [TailRec](#tailrec)
  - [NextTailRec](#nexttailrec)
  - [DoneTailRec](#donetailrec)

---

## ContCrash

```dart
sealed class ContCrash
```

Represents unexpected exceptions (crashes) that occur during continuation execution.

Unlike typed errors on the else channel (type `F`), crashes represent unrecoverable failures — exceptions that were not part of the expected control flow. `ContCrash` is a sealed class with three subtypes representing different crash scenarios.

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
Combines multiple crashes from a list operation into a `CollectedCrash`.

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
- `crashes: Map<int, ContCrash>` — A map from the index in the original list to the crash

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

## ContRuntime

```dart
final class ContRuntime<E>
```

Provides runtime context for continuation execution.

`ContRuntime` carries the environment during the execution of a `Cont`. It allows continuations to access contextual information.

**Methods:**

```dart
E env()
```
Returns the environment value of type `E`. The environment provides contextual information such as configuration, dependencies, or any data that should flow through the continuation execution.

```dart
ContRuntime<E2> copyUpdateEnv<E2>(E2 env)
```
Creates a copy of this runtime with a different environment. Returns a new `ContRuntime` with the provided environment. This is used by `local` and related methods to modify the environment context.

- **Parameters:**
  - `env`: The new environment value to use

---

## ContObserver

```dart
sealed class ContObserver<F, A>
```

An observer that handles all three outcome channels of a continuation: crash, error, and success.

`ContObserver` provides the callback mechanism for receiving results from a `Cont` execution. It encapsulates handlers for crashes (unexpected exceptions), errors (typed business failures), and successful values.

`ContObserver` has a private constructor. Instances cannot be created directly. Instead, new observers are derived from existing ones using the copy methods. The initial observer is provided by the runtime when a continuation is executed (e.g., inside `Cont.fromRun` or `decorate`).

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

The following extension methods widen a `Never`-typed channel to an arbitrary type. When an observer's success or error type is `Never` (meaning that channel can never fire), these methods replace the unreachable callback with a no-op. Since `ContObserver` can also be used directly where a wider type is expected, they are mainly a convenience for spelling out the target type.

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

---

## TailRec

```dart
sealed class TailRec<S, A>
```

One step of [`Cont.tailRecM`](construction.md#conttailrecm): continue the loop with a new state, or finish it with a result.

- **Type Parameters:**
  - `S`: The loop state
  - `A`: The result of the loop

**Creating steps** (the case classes have no public constructors):

```dart
static TailRec<S, A> next<S, A>(S state)
```
Continues the loop with `state`. Creates a `NextTailRec`.

```dart
static TailRec<S, A> done<S, A>(A result)
```
Finishes the loop with `result`. Creates a `DoneTailRec`.

**Equality:** steps compare by value. Two `next` steps are equal when their states are equal, and two `done` steps when their results are equal; a `next` step never equals a `done` step.

**Example:**
```dart
TailRec<int, String> step(int n) {
  return n < 3 ? TailRec.next(n + 1) : TailRec.done('finished at $n');
}

switch (step(1)) {
  case NextTailRec(state: final state):
    print('next: $state');
  case DoneTailRec(result: final result):
    print('done: $result');
}
```

---

### NextTailRec

```dart
final class NextTailRec<S, A> extends TailRec<S, A>
```

A `TailRec` step that continues the loop. Created with `TailRec.next`.

**Fields:**
- `state: S` — The state for the next iteration

---

### DoneTailRec

```dart
final class DoneTailRec<S, A> extends TailRec<S, A>
```

A `TailRec` step that finishes the loop. Created with `TailRec.done`.

**Fields:**
- `result: A` — The result of the loop
