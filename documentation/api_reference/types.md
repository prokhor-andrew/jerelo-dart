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
- [ContRuntime](#contruntime)
- [ContObserver](#contobserver)
  - [SafeObserver](#safeobserver)
- [ContCancelToken](#contcanceltoken)

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
result.match(
  (value) => print('Parsed: $value'),
  (crash) => print('Failed: ${crash.error}'),
);
```

---

### NormalCrash

```dart
final class NormalCrash extends ContCrash
```

A single exception with its stack trace.

**Fields:**
- `error: Object` — The exception that was thrown
- `stackTrace: StackTrace` — The stack trace captured at the point of the exception

---

### MergedCrash

```dart
final class MergedCrash extends ContCrash
```

Two crashes combined from a two-way parallel operation (e.g., `both`, `either`).

**Fields:**
- `left: ContCrash` — The crash from the left continuation
- `right: ContCrash` — The crash from the right continuation

**Constructor:**

```dart
const MergedCrash(ContCrash left, ContCrash right)
```

---

### CollectedCrash

```dart
final class CollectedCrash extends ContCrash
```

Multiple crashes from a list operation (e.g., `all`, `any`), indexed by position.

**Fields:**
- `crashes: Map<int, ContCrash>` — A map from the index in the original list to the crash

**Constructor:**

```dart
const CollectedCrash(Map<int, ContCrash> crashes)
```

---

## CrashOr

```dart
sealed class CrashOr<T>
```

A result type representing either a value or a crash. Returned by `ContCrash.tryCatch`.

**Methods:**

```dart
R match<R>(
  R Function(T value) ifValue,
  R Function(NormalCrash crash) ifCrash,
)
```
Pattern-matches on the result, calling `ifValue` if the computation succeeded or `ifCrash` if it threw.

- **Parameters:**
  - `ifValue`: Called with the value if no crash occurred
  - `ifCrash`: Called with the `NormalCrash` if an exception was thrown

**Example:**
```dart
final result = ContCrash.tryCatch(() => riskyOperation());
final output = result.match(
  (value) => 'Got: $value',
  (crash) => 'Crashed: ${crash.error}',
);
```

---

## ContRuntime

```dart
final class ContRuntime<E>
```

Provides runtime context for continuation execution.

`ContRuntime` encapsulates the environment and cancellation state during the execution of a `Cont`. It allows continuations to access contextual information and check for cancellation.

**Fields & Methods:**

```dart
bool Function() isCancelled
```
Function that checks whether the continuation execution has been cancelled. Returns `true` if the execution should be stopped, `false` otherwise. Continuations should check this regularly to support cooperative cancellation.

```dart
E env()
```
Returns the environment value of type `E`. The environment provides contextual information such as configuration, dependencies, or any data that should flow through the continuation execution.

```dart
ContRuntime<E2> copyUpdateEnv<E2>(E2 env)
```
Creates a copy of this runtime with a different environment. Returns a new `ContRuntime` with the provided environment while preserving the cancellation function. This is used by `local` and related methods to modify the environment context.

- **Parameters:**
  - `env`: The new environment value to use

```dart
ContRuntime<E> extendCancellation(bool Function() anotherIsCancelled)
```
Creates a copy of this runtime with an additional cancellation source. The resulting runtime reports cancelled if either the original or the new cancellation function returns `true`.

- **Parameters:**
  - `anotherIsCancelled`: An additional cancellation check to combine with the existing one

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

The following extension methods widen `Never`-typed channels to arbitrary types. When an observer's success or error type is `Never` (meaning that channel can never fire), these methods replace the unreachable callback with a no-op so the observer can be used in a broader generic context.

```dart
// On ContObserver<F, A>:
ContObserver<F, A> thenAbsurdify()
```
Widens the success channel if its type is `Never`. If this observer has type `ContObserver<F, Never>`, returns a copy typed as `ContObserver<F, A>` with a no-op `onThen` callback. Otherwise returns this observer unchanged.

```dart
// On ContObserver<F, A>:
ContObserver<F, A> elseAbsurdify()
```
Widens the error channel if its type is `Never`. If this observer has type `ContObserver<Never, A>`, returns a copy typed as `ContObserver<F, A>` with a no-op `onElse` callback. Otherwise returns this observer unchanged.

```dart
// On ContObserver<F, A>:
ContObserver<F, A> absurdify()
```
Widens both the success and error channels if either is `Never`. Equivalent to calling `thenAbsurdify()` followed by `elseAbsurdify()`.

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

Used by `Cont.fromRun` to wrap user-provided callbacks with idempotence and exception safety.

**Fields:**
- `isUsed: bool Function()` — Returns `true` if any callback on this observer has already been invoked

---

## ContCancelToken

```dart
final class ContCancelToken
```

A token used to cooperatively cancel a running continuation.

Returned by `Cont.run`, this token provides a way to signal cancellation to a running computation and to query its current cancellation state.

Cancellation is cooperative: calling `cancel` sets an internal flag that the runtime polls via `isCancelled`. The computation checks this flag at safe points and stops work when it detects cancellation.

**Methods:**

```dart
bool isCancelled()
```
Returns `true` if `cancel` has been called on this token, `false` otherwise.

```dart
void cancel()
```
Signals cancellation to the running computation. After this call, `isCancelled()` will return `true` and the runtime will detect the cancellation at the next polling point. Calling this method multiple times is safe but has no additional effect.

**Example:**
```dart
final token = computation.run(
  env,
  onThen: (value) => print('Success: $value'),
);

// Later, cancel the computation
token.cancel();

// Check cancellation state
print(token.isCancelled()); // true
```
