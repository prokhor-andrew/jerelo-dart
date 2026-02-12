# Types

Core types used throughout the Jerelo continuation library.

---

## Table of Contents

- [ContError](#conterror)
- [ContRuntime](#contruntime)
- [ContObserver](#contobserver)

---

## ContError

```dart
final class ContError
```

An immutable error container used throughout the continuation system.

Wraps an error object together with its stack trace, providing a consistent way to propagate error information through continuation chains.

**Fields:**
- `error: Object` - The error object that was caught or created
- `stackTrace: StackTrace` - The stack trace captured at the point where the error occurred

**Static Factory Methods:**

```dart
static ContError withStackTrace(Object error, StackTrace st)
```
Creates an error wrapper from an error and an existing stack trace. Use this when you have already caught an error and its associated stack trace, for example inside a `catch` block.

- **Parameters:**
  - `error`: The error object to wrap
  - `st`: The stack trace associated with the error

```dart
static ContError withNoStackTrace(Object error)
```
Creates an error wrapper with an empty stack trace. Use this when the stack trace is not available or not relevant, for example when creating a logical termination reason that does not originate from a thrown exception.

- **Parameters:**
  - `error`: The error object to wrap

```dart
static ContError capture(Object error)
```
Creates an error wrapper and captures the current stack trace automatically. Use this when you want to create an error at the call site and record where it was created.

- **Parameters:**
  - `error`: The error object to wrap

**Example:**
```dart
// From a catch block — use withStackTrace
try {
  riskyOperation();
} catch (error, st) {
  observer.onElse([ContError.withStackTrace(error, st)]);
}

// Logical termination without a stack trace
ContError.withNoStackTrace('User not found');

// Capture the stack trace at the call site
ContError.capture('Something went wrong');
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
bool isCancelled()
```
Function that checks whether the continuation execution has been cancelled. Returns `true` if the execution should be stopped, `false` otherwise. Continuations should check this regularly to support cooperative cancellation.

```dart
void onPanic(ContError fatal)
```
Callback invoked when a fatal, unrecoverable error occurs during continuation execution. Unlike `ContObserver.onElse`, which handles expected termination errors within the normal control flow, `onPanic` is reserved for situations that violate internal invariants (e.g. an observer callback throwing an exception). The default implementation re-throws the error inside a microtask so it surfaces as an unhandled exception.

```dart
E env()
```
Returns the environment value of type `E`. The environment provides contextual information such as configuration, dependencies, or any data that should flow through the continuation execution.

```dart
ContRuntime<E2> copyUpdateEnv<E2>(E2 env)
```
Creates a copy of this runtime with a different environment. Returns a new `ContRuntime` with the provided environment while preserving the cancellation function and panic handler. This is used by `local` and related methods to modify the environment context.

- **Parameters:**
  - `env`: The new environment value to use

---

## ContObserver

```dart
final class ContObserver<A>
```

An observer that handles both success and termination cases of a continuation.

`ContObserver` provides the callback mechanism for receiving results from a `Cont` execution. It encapsulates handlers for both successful values and termination (failure) scenarios.

**Methods:**

```dart
void onThen(A value)
```
The callback function invoked when the continuation produces a successful value.

```dart
void onElse([List<ContError> errors = const []])
```
Invokes the termination callback with the provided errors.

- **Parameters:**
  - `errors`: List of errors that caused termination. Defaults to an empty list

```dart
ContObserver<A> copyUpdateOnElse(void Function(List<ContError> errors) onElse)
```
Creates a new observer with an updated termination handler. Returns a copy of this observer with a different termination callback, while preserving the value callback.

- **Parameters:**
  - `onElse`: The new termination handler to use

```dart
ContObserver<A2> copyUpdateOnValue<A2>(void Function(A2 value) onThen)
```
Creates a new observer with an updated value handler and potentially different type. Returns a copy of this observer with a different value callback type, while preserving the termination callback.

- **Parameters:**
  - `onThen`: The new value handler to use
