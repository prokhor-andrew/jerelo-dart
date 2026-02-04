# Jerelo API Documentation

Complete reference for all public types and APIs in the Jerelo continuation library.

---

## Table of Contents

- [Core Types](#core-types)
  - [Cont](#cont)
  - [ContError](#conterror)
  - [ContPolicy](#contpolicy)
  - [ContRuntime](#contruntime)
  - [ContObserver](#contobserver)
- [Policy Types](#policy-types)
  - [SequencePolicy](#sequencepolicy)
  - [MergeWhenAllPolicy](#mergewhenallpolicy)
  - [QuitFastPolicy](#quitfastpolicy)
- [Extensions](#extensions)
  - [ContFlattenExtension](#contflattenextension)
  - [ContRunExtension](#contrunextension)
- [API Reference](#api-reference)
  - [Constructors & Static Methods](#constructors--static-methods)
  - [Execution Methods](#execution-methods)
  - [Transformation Methods](#transformation-methods)
  - [Chaining Methods](#chaining-methods)
  - [Error Handling Methods](#error-handling-methods)
  - [Environment Methods](#environment-methods)
  - [Parallel Execution Methods](#parallel-execution-methods)
  - [Loop & Conditional Methods](#loop--conditional-methods)
  - [Resource Management](#resource-management)

---

## Core Types

### Cont

```dart
final class Cont<E, A>
```

A continuation monad representing a computation that will eventually produce a value of type `A` or terminate with errors.

**Type Parameters:**
- `E`: The environment type providing context for the continuation execution
- `A`: The value type that the continuation produces upon success

`Cont` provides a powerful abstraction for managing asynchronous operations, error handling, and composition of effectful computations. It follows the continuation-passing style where computations are represented as functions that take callbacks for success and failure.

---

### ContError

```dart
final class ContError
```

An immutable error container used throughout the continuation system.

Wraps an error object together with its stack trace, providing a consistent way to propagate error information through continuation chains.

**Fields:**
- `error: Object` - The error object that was caught or created
- `stackTrace: StackTrace` - The stack trace captured at the point where the error occurred

**Constructor:**
```dart
const ContError(Object error, StackTrace stackTrace)
```

Creates an error wrapper containing an error and stack trace.

---

### ContPolicy

```dart
sealed class ContPolicy<T>
```

Execution policy for parallel continuation operations.

Defines how multiple continuations should be executed and how their results or errors should be combined. Different policies provide different trade-offs between execution order, error handling, and result combination.

**Available Policies:**
- [SequencePolicy](#sequencepolicy): Executes operations sequentially, one after another
- [MergeWhenAllPolicy](#mergewhenallpolicy): Waits for all operations to complete and merges errors (for `all`/`both`) or results (for `any`/`either`)
- [QuitFastPolicy](#quitfastpolicy): Terminates as soon as one operation fails (for `all`/`both`) or succeeds (for `any`/`either`)

**Static Factory Methods:**

```dart
static ContPolicy<T> sequence<T>()
```
Creates a sequential execution policy. Operations are executed one after another in order. For `all`/`both`, execution stops at the first failure. For `any`/`either`, execution continues until one succeeds or all fail.

```dart
static MergeWhenAllPolicy<T> mergeWhenAll<T>(T Function(T acc, T value) combine)
```
Creates a merge-when-all policy with a custom combiner. All operations are executed in parallel. Results or errors are accumulated using the provided `combine` function. The function receives the accumulated value and the new value, returning the combined result.

- **Parameters:**
  - `combine`: Function to merge accumulated and new values

```dart
static ContPolicy<T> quitFast<T>()
```
Creates a quit-fast policy. Terminates immediately when a decisive result is reached:
- For `all`/`both`: quits on the first failure
- For `any`/`either`: quits on the first success

Provides the fastest feedback but may leave other operations running.

---

### ContRuntime

```dart
final class ContRuntime<E>
```

Provides runtime context for continuation execution.

`ContRuntime` encapsulates the environment and cancellation state during the execution of a `Cont`. It allows continuations to access contextual information and check for cancellation.

**Methods:**

```dart
E env()
```
Returns the environment value of type `E`. The environment provides contextual information such as configuration, dependencies, or any data that should flow through the continuation execution.

```dart
bool isCancelled()
```
Function that checks whether the continuation execution has been cancelled. Returns `true` if the execution should be stopped, `false` otherwise. Continuations should check this regularly to support cooperative cancellation.

```dart
ContRuntime<E2> copyUpdateEnv<E2>(E2 env)
```
Creates a copy of this runtime with a different environment. Returns a new `ContRuntime` with the provided environment while preserving the cancellation function. This is used by `local` and related methods to modify the environment context.

- **Parameters:**
  - `env`: The new environment value to use

---

### ContObserver

```dart
final class ContObserver<A>
```

An observer that handles both success and termination cases of a continuation.

`ContObserver` provides the callback mechanism for receiving results from a `Cont` execution. It encapsulates handlers for both successful values and termination (failure) scenarios.

**Methods:**

```dart
void onValue(A value)
```
The callback function invoked when the continuation produces a successful value.

```dart
void onTerminate([List<ContError> errors = const []])
```
Invokes the termination callback with the provided errors.

- **Parameters:**
  - `errors`: List of errors that caused termination. Defaults to an empty list

```dart
ContObserver<A> copyUpdateOnTerminate(void Function(List<ContError> errors) onTerminate)
```
Creates a new observer with an updated termination handler. Returns a copy of this observer with a different termination callback, while preserving the value callback.

- **Parameters:**
  - `onTerminate`: The new termination handler to use

```dart
ContObserver<A2> copyUpdateOnValue<A2>(void Function(A2 value) onValue)
```
Creates a new observer with an updated value handler and potentially different type. Returns a copy of this observer with a different value callback type, while preserving the termination callback.

- **Parameters:**
  - `onValue`: The new value handler to use

---

## Policy Types

### SequencePolicy

```dart
final class SequencePolicy<T> extends ContPolicy<T>
```

Sequential execution policy.

Executes continuations one after another in order. Stops at the first failure for `all`/`both` operations, or at the first success for `any`/`either` operations.

---

### MergeWhenAllPolicy

```dart
final class MergeWhenAllPolicy<T> extends ContPolicy<T>
```

Merge-when-all execution policy.

Executes all continuations in parallel and waits for all to complete. Combines results or errors using the provided `combine` function.

**Fields:**
- `combine: T Function(T acc, T value)` - Function to combine accumulated and new values

---

### QuitFastPolicy

```dart
final class QuitFastPolicy<T> extends ContPolicy<T>
```

Quit-fast execution policy.

Terminates as soon as a decisive result is reached:
- For `all`/`both`: terminates on first failure
- For `any`/`either`: terminates on first success

Provides fastest feedback but other operations may continue running.

---

## Extensions

### ContFlattenExtension

```dart
extension ContFlattenExtension<E, A> on Cont<E, Cont<E, A>>
```

Extension providing flatten operation for nested continuations.

**Methods:**

```dart
Cont<E, A> flatten()
```
Flattens a nested `Cont` structure. Converts `Cont<E, Cont<E, A>>` to `Cont<E, A>`. Equivalent to `thenDo((contA) => contA)`.

---

### ContRunExtension

```dart
extension ContRunExtension<E> on Cont<E, Never>
```

Extension for running continuations that never produce a value.

This extension provides specialized methods for `Cont<E, Never>` where only termination is expected, simplifying the API by removing the unused value callback.

**Methods:**

```dart
void trap(E env, void Function(List<ContError>) onTerminate)
```
Executes the continuation expecting only termination. This is a convenience method for `Cont<E, Never>` that executes the continuation with only a termination handler, since a value callback would never be called for a `Cont<E, Never>`.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onTerminate`: Callback invoked when the continuation terminates with errors

**Example:**
```dart
final cont = Cont.terminate<MyEnv, Never>([ContError(Exception('Failed'), StackTrace.current)]);
cont.trap(myEnv, (errors) {
  print('Terminated with ${errors.length} error(s)');
});
```

---

## API Reference

### Constructors & Static Methods

#### Cont.fromRun

```dart
static Cont<E, A> fromRun<E, A>(void Function(ContRuntime<E> runtime, ContObserver<A> observer) run)
```

Creates a `Cont` from a run function that accepts an observer.

Constructs a continuation with guaranteed idempotence and exception catching. The run function receives an observer with `onValue` and `onTerminate` callbacks. The callbacks should be called as the last instruction in the run function or saved to be called later.

- **Parameters:**
  - `run`: Function that executes the continuation and calls observer callbacks

---

#### Cont.fromDeferred

```dart
static Cont<E, A> fromDeferred<E, A>(Cont<E, A> Function() thunk)
```

Creates a `Cont` from a deferred continuation computation.

Lazily evaluates a continuation-returning function. The inner `Cont` is not created until the outer one is executed.

- **Parameters:**
  - `thunk`: Function that returns a `Cont` when called

---

#### Cont.of

```dart
static Cont<E, A> of<E, A>(A value)
```

Creates a `Cont` that immediately succeeds with a value.

Identity operation that wraps a pure value in a continuation context.

- **Parameters:**
  - `value`: The value to wrap

---

#### Cont.terminate

```dart
static Cont<E, A> terminate<E, A>([List<ContError> errors = const []])
```

Creates a `Cont` that immediately terminates with optional errors.

Creates a continuation that terminates without producing a value. Used to represent failure states.

- **Parameters:**
  - `errors`: List of errors to terminate with. Defaults to an empty list

---

#### Cont.ask

```dart
static Cont<E, E> ask<E>()
```

Retrieves the current environment value.

Accesses the environment of type `E` from the runtime context. This is used to read configuration, dependencies, or any contextual information that flows through the continuation execution.

Returns a continuation that succeeds with the environment value.

---

### Execution Methods

#### run

```dart
void run(E env, void Function(List<ContError> errors) onTerminate, void Function(A value) onValue)
```

Executes the continuation with separate callbacks for termination and value.

Initiates execution of the continuation with separate handlers for success and failure cases.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onTerminate`: Callback invoked when the continuation terminates with errors
  - `onValue`: Callback invoked when the continuation produces a successful value

---

#### ff

```dart
void ff(E env)
```

Executes the continuation in a fire-and-forget manner.

Runs the continuation without waiting for the result. Both success and failure outcomes are ignored. This is useful for side-effects that should run asynchronously without blocking or requiring error handling.

- **Parameters:**
  - `env`: The environment value to provide as context during execution

---

### Transformation Methods

#### map

```dart
Cont<E, A2> map<A2>(A2 Function(A value) f)
```

Transforms the value inside a `Cont` using a pure function.

Applies a function to the successful value of the continuation without affecting the termination case.

- **Parameters:**
  - `f`: Transformation function to apply to the value

---

#### map0

```dart
Cont<E, A2> map0<A2>(A2 Function() f)
```

Transforms the value inside a `Cont` using a zero-argument function.

Similar to `map` but ignores the current value and computes a new one.

- **Parameters:**
  - `f`: Zero-argument transformation function

---

#### as

```dart
Cont<E, A2> as<A2>(A2 value)
```

Replaces the value inside a `Cont` with a constant.

Discards the current value and replaces it with a fixed value.

- **Parameters:**
  - `value`: The constant value to replace with

---

#### hoist

```dart
Cont<E, A> hoist(void Function(void Function(ContRuntime<E>, ContObserver<A>) run, ContRuntime<E> runtime, ContObserver<A> observer) f)
```

Transforms the execution of the continuation using a natural transformation.

Applies a function that wraps or modifies the underlying run behavior. This is useful for intercepting execution to add middleware-like behavior such as logging, timing, or modifying how observers receive callbacks.

The transformation function receives both the original run function and the observer, allowing custom execution behavior to be injected.

- **Parameters:**
  - `f`: A transformation function that receives the run function and observer, and implements custom execution logic by calling the run function with the observer at the appropriate time

**Example:**
```dart
// Add logging around execution
final logged = cont.hoist((run, runtime, observer) {
  print('Starting execution');
  run(runtime, observer);
  print('Execution initiated');
});
```

---

### Chaining Methods

#### thenDo

```dart
Cont<E, A2> thenDo<A2>(Cont<E, A2> Function(A value) f)
```

Chains a `Cont`-returning function to create dependent computations.

Monadic bind operation. Sequences continuations where the second depends on the result of the first.

- **Parameters:**
  - `f`: Function that takes a value and returns a continuation

---

#### thenDo0

```dart
Cont<E, A2> thenDo0<A2>(Cont<E, A2> Function() f)
```

Chains a `Cont`-returning zero-argument function.

Similar to `thenDo` but ignores the current value.

- **Parameters:**
  - `f`: Zero-argument function that returns a continuation

---

#### thenTap

```dart
Cont<E, A> thenTap<A2>(Cont<E, A2> Function(A value) f)
```

Chains a side-effect continuation while preserving the original value.

Executes a continuation for its side effects, then returns the original value.

- **Parameters:**
  - `f`: Side-effect function that returns a continuation

---

#### thenTap0

```dart
Cont<E, A> thenTap0<A2>(Cont<E, A2> Function() f)
```

Chains a zero-argument side-effect continuation.

Similar to `thenTap` but with a zero-argument function.

- **Parameters:**
  - `f`: Zero-argument side-effect function

---

#### thenZip

```dart
Cont<E, A3> thenZip<A2, A3>(Cont<E, A2> Function(A value) f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines two continuation values.

Sequences two continuations and combines their results using the provided function.

- **Parameters:**
  - `f`: Function to produce the second continuation from the first value
  - `combine`: Function to combine both values into a result

---

#### thenZip0

```dart
Cont<E, A3> thenZip0<A2, A3>(Cont<E, A2> Function() f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines with a zero-argument function.

Similar to `thenZip` but the second continuation doesn't depend on the first value.

- **Parameters:**
  - `f`: Zero-argument function to produce the second continuation
  - `combine`: Function to combine both values into a result

---

#### thenFork

```dart
Cont<E, A> thenFork<A2>(Cont<E, A2> Function(A a) f)
```

Executes a side-effect continuation in a fire-and-forget manner.

Unlike `thenTap`, this method does not wait for the side-effect to complete. The side-effect continuation is started immediately, and the original value is returned without delay. Any errors from the side-effect are silently ignored.

- **Parameters:**
  - `f`: Function that takes the current value and returns a side-effect continuation

---

#### thenFork0

```dart
Cont<E, A> thenFork0<A2>(Cont<E, A2> Function() f)
```

Executes a zero-argument side-effect continuation in a fire-and-forget manner.

Similar to `thenFork` but ignores the current value.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

---

### Error Handling Methods

#### elseDo

```dart
Cont<E, A> elseDo(Cont<E, A> Function(List<ContError> errors) f)
```

Provides a fallback continuation in case of termination.

If the continuation terminates, executes the fallback. If the fallback also terminates, only the fallback's errors are propagated (the original errors are discarded).

To accumulate errors from both attempts, use `elseZip` instead.

- **Parameters:**
  - `f`: Function that receives errors and produces a fallback continuation

---

#### elseDo0

```dart
Cont<E, A> elseDo0(Cont<E, A> Function() f)
```

Provides a zero-argument fallback continuation.

Similar to `elseDo` but doesn't use the error information.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation

---

#### elseTap

```dart
Cont<E, A> elseTap(Cont<E, A> Function(List<ContError> errors) f)
```

Executes a side-effect continuation on termination.

If the continuation terminates, executes the side-effect continuation for its effects. The behavior depends on the side-effect's outcome:

- If the side-effect terminates: Returns the original errors (ignoring side-effect errors)
- If the side-effect succeeds: Returns the side-effect's success value, effectively recovering from the original termination

This means the operation can recover from termination if the side-effect succeeds. If you want to always propagate the original termination regardless of the side-effect's outcome, use `elseFork` instead.

- **Parameters:**
  - `f`: Function that receives the original errors and returns a side-effect continuation

---

#### elseTap0

```dart
Cont<E, A> elseTap0(Cont<E, A> Function() f)
```

Executes a zero-argument side-effect continuation on termination.

Similar to `elseTap` but ignores the error information.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

---

#### elseZip

```dart
Cont<E, A> elseZip(Cont<E, A> Function(List<ContError>) f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Attempts a fallback continuation and combines errors from both attempts.

If the continuation terminates, executes the fallback. If the fallback also terminates, combines errors from both attempts using the provided `combine` function before terminating.

Unlike `elseDo`, which only keeps the second error list, this method accumulates and combines errors from both attempts.

- **Parameters:**
  - `f`: Function that receives original errors and produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

---

#### elseZip0

```dart
Cont<E, A> elseZip0(Cont<E, A> Function() f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Zero-argument version of `elseZip`.

Similar to `elseZip` but doesn't use the original error information when producing the fallback continuation.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

---

#### elseFork

```dart
Cont<E, A> elseFork<A2>(Cont<E, A2> Function(List<ContError> errors) f)
```

Executes a side-effect continuation on termination in a fire-and-forget manner.

If the continuation terminates, starts the side-effect continuation without waiting for it to complete. Unlike `elseTap`, this does not wait for the side-effect to finish before propagating the termination. Any errors from the side-effect are silently ignored.

- **Parameters:**
  - `f`: Function that returns a side-effect continuation

---

#### elseFork0

```dart
Cont<E, A> elseFork0<A2>(Cont<E, A2> Function() f)
```

Executes a zero-argument side-effect continuation on termination in a fire-and-forget manner.

Similar to `elseFork` but ignores the error information.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

---

### Environment Methods

#### local

```dart
Cont<E2, A> local<E2>(E Function(E2) f)
```

Runs this continuation with a transformed environment.

Transforms the environment from `E2` to `E` using the provided function, then executes this continuation with the transformed environment. This allows adapting the continuation to work in a context with a different environment type.

- **Parameters:**
  - `f`: Function that transforms the outer environment to the inner environment

---

#### local0

```dart
Cont<E2, A> local0<E2>(E Function() f)
```

Runs this continuation with a new environment from a zero-argument function.

Similar to `local` but obtains the environment from a zero-argument function instead of transforming the existing environment.

- **Parameters:**
  - `f`: Zero-argument function that provides the new environment

---

#### scope

```dart
Cont<E2, A> scope<E2>(E value)
```

Runs this continuation with a fixed environment value.

Replaces the environment context with the provided value for the execution of this continuation. This is useful for providing configuration, dependencies, or context to a continuation.

- **Parameters:**
  - `value`: The environment value to use

---

#### thenDoWithEnv

```dart
Cont<E, A2> thenDoWithEnv<A2>(Cont<E, A2> Function(E env, A a) f)
```

Chains a continuation-returning function that has access to both the value and environment.

Similar to `thenDo`, but the function receives both the current value and the environment. This is useful when the next computation needs access to configuration or context from the environment.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a continuation

---

#### thenDoWithEnv0

```dart
Cont<E, A2> thenDoWithEnv0<A2>(Cont<E, A2> Function(E env) f)
```

Chains a continuation-returning function with access to the environment only.

Similar to `thenDoWithEnv`, but the function only receives the environment and ignores the current value. This is useful when the next computation needs access to configuration or context but doesn't depend on the previous value.

- **Parameters:**
  - `f`: Function that takes the environment and returns a continuation

---

#### thenTapWithEnv

```dart
Cont<E, A> thenTapWithEnv<A2>(Cont<E, A2> Function(E env, A a) f)
```

Chains a side-effect continuation with access to both the environment and value.

Similar to `thenTap`, but the side-effect function receives both the current value and the environment. After executing the side-effect, returns the original value. This is useful for logging, monitoring, or other side-effects that need access to both the value and configuration context.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a side-effect continuation

---

#### thenTapWithEnv0

```dart
Cont<E, A> thenTapWithEnv0<A2>(Cont<E, A2> Function(E env) f)
```

Chains a side-effect continuation with access to the environment only.

Similar to `thenTapWithEnv`, but the side-effect function only receives the environment and ignores the current value. After executing the side-effect, returns the original value.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

---

#### thenZipWithEnv

```dart
Cont<E, A3> thenZipWithEnv<A2, A3>(Cont<E, A2> Function(E env, A value) f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines two continuations with access to the environment.

Similar to `thenZip`, but the function producing the second continuation receives both the current value and the environment. This is useful when the second computation needs access to configuration or context.

- **Parameters:**
  - `f`: Function that takes the environment and value, and produces the second continuation
  - `combine`: Function to combine both values into a result

---

#### thenZipWithEnv0

```dart
Cont<E, A3> thenZipWithEnv0<A2, A3>(Cont<E, A2> Function(E env) f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines with a continuation that has access to the environment only.

Similar to `thenZipWithEnv`, but the function producing the second continuation only receives the environment and ignores the current value.

- **Parameters:**
  - `f`: Function that takes the environment and produces the second continuation
  - `combine`: Function to combine both values into a result

---

#### thenForkWithEnv

```dart
Cont<E, A> thenForkWithEnv<A2>(Cont<E, A2> Function(E env, A a) f)
```

Executes a side-effect continuation in a fire-and-forget manner with access to the environment.

Similar to `thenFork`, but the side-effect function receives both the current value and the environment. The side-effect is started immediately without waiting, and any errors are silently ignored.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a side-effect continuation

---

#### thenForkWithEnv0

```dart
Cont<E, A> thenForkWithEnv0<A2>(Cont<E, A2> Function(E env) f)
```

Executes a side-effect continuation in a fire-and-forget manner with access to the environment only.

Similar to `thenForkWithEnv`, but the side-effect function only receives the environment and ignores the current value.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

---

#### elseDoWithEnv

```dart
Cont<E, A> elseDoWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f)
```

Provides a fallback continuation that has access to both errors and environment.

Similar to `elseDo`, but the fallback function receives both the errors and the environment. This is useful when error recovery needs access to configuration or context from the environment.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a fallback continuation

---

#### elseDoWithEnv0

```dart
Cont<E, A> elseDoWithEnv0(Cont<E, A> Function(E env) f)
```

Provides a fallback continuation with access to the environment only.

Similar to `elseDoWithEnv`, but the fallback function only receives the environment and ignores the error information. This is useful when error recovery needs access to configuration but doesn't need to inspect the errors.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback continuation

---

#### elseTapWithEnv

```dart
Cont<E, A> elseTapWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f)
```

Executes a side-effect continuation on termination with access to the environment.

Similar to `elseTap`, but the side-effect function receives both the errors and the environment. This allows error-handling side-effects (like logging or reporting) to access configuration or context information.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a side-effect continuation

---

#### elseTapWithEnv0

```dart
Cont<E, A> elseTapWithEnv0(Cont<E, A> Function(E env) f)
```

Executes a side-effect continuation on termination with access to the environment only.

Similar to `elseTapWithEnv`, but the side-effect function only receives the environment and ignores the error information.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

---

#### elseZipWithEnv

```dart
Cont<E, A> elseZipWithEnv(Cont<E, A> Function(E env, List<ContError>) f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Attempts a fallback continuation with access to the environment and combines errors.

Similar to `elseZip`, but the fallback function receives both the original errors and the environment. If both the original attempt and fallback fail, their errors are combined using the `combine` function. This is useful when error recovery strategies need access to configuration or context.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

---

#### elseZipWithEnv0

```dart
Cont<E, A> elseZipWithEnv0(Cont<E, A> Function(E env) f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Attempts a fallback continuation with access to the environment only and combines errors.

Similar to `elseZipWithEnv`, but the fallback function only receives the environment and ignores the original error information.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

---

#### elseForkWithEnv

```dart
Cont<E, A> elseForkWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f)
```

Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment.

Similar to `elseFork`, but the side-effect function receives both the errors and the environment. The side-effect is started without waiting for it to complete, and any errors from the side-effect are silently ignored.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a side-effect continuation

---

#### elseForkWithEnv0

```dart
Cont<E, A> elseForkWithEnv0(Cont<E, A> Function(E env) f)
```

Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment only.

Similar to `elseForkWithEnv`, but the side-effect function only receives the environment and ignores the error information.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

---

### Parallel Execution Methods

#### Cont.both

```dart
static Cont<E, A3> both<E, A1, A2, A3>(
  Cont<E, A1> left,
  Cont<E, A2> right,
  A3 Function(A1 a, A2 a2) combine, {
  required ContPolicy<List<ContError>> policy,
})
```

Runs two continuations and combines their results according to the specified policy.

Executes both continuations. Both must succeed for the result to be successful; if either fails, the entire operation fails. When both succeed, their values are combined using `combine`.

The execution behavior depends on the provided `policy`:

- **SequencePolicy**: Runs `left` then `right` sequentially
- **MergeWhenAllPolicy**: Runs both in parallel, waits for both to complete, and merges errors if both fail
- **QuitFastPolicy**: Runs both in parallel, terminates immediately if either fails

- **Parameters:**
  - `left`: First continuation to execute
  - `right`: Second continuation to execute
  - `combine`: Function to combine both successful values
  - `policy`: Execution policy determining how continuations are run and errors are handled

---

#### and

```dart
Cont<E, A3> and<A2, A3>(
  Cont<E, A2> right,
  A3 Function(A a, A2 a2) combine, {
  required ContPolicy<List<ContError>> policy,
})
```

Instance method for combining this continuation with another.

Convenient instance method wrapper for `Cont.both`. Executes this continuation and `right` according to the specified `policy`, then combines their values.

- **Parameters:**
  - `right`: The other continuation to combine with
  - `combine`: Function to combine both successful values
  - `policy`: Execution policy determining how continuations are run and errors are handled

---

#### Cont.all

```dart
static Cont<E, List<A>> all<E, A>(
  List<Cont<E, A>> list, {
  required ContPolicy<List<ContError>> policy,
})
```

Runs multiple continuations and collects all results according to the specified policy.

Executes all continuations in `list` and collects their values into a list. The execution behavior depends on the provided `policy`:

- **SequencePolicy**: Runs continuations one by one in order, stops at first failure
- **MergeWhenAllPolicy**: Runs all in parallel, waits for all to complete, and merges errors if any fail
- **QuitFastPolicy**: Runs all in parallel, terminates immediately on first failure

- **Parameters:**
  - `list`: List of continuations to execute
  - `policy`: Execution policy determining how continuations are run and errors are handled

---

#### Cont.either

```dart
static Cont<E, A> either<E, A>(
  Cont<E, A> left,
  Cont<E, A> right,
  List<ContError> Function(List<ContError>, List<ContError>) combine, {
  required ContPolicy<A> policy,
})
```

Races two continuations, returning the first successful value.

Executes both continuations and returns the result from whichever succeeds first. If both fail, combines their errors using `combine`. The execution behavior depends on the provided `policy`:

- **SequencePolicy**: Tries `left` first, then `right` if `left` fails
- **MergeWhenAllPolicy**: Runs both in parallel, returns first success or merges results/errors if both complete
- **QuitFastPolicy**: Runs both in parallel, returns immediately on first success

- **Parameters:**
  - `left`: First continuation to try
  - `right`: Second continuation to try
  - `combine`: Function to combine error lists if both fail
  - `policy`: Execution policy determining how continuations are run

---

#### or

```dart
Cont<E, A> or(
  Cont<E, A> right,
  List<ContError> Function(List<ContError>, List<ContError>) combine, {
  required ContPolicy<A> policy,
})
```

Instance method for racing this continuation with another.

Convenient instance method wrapper for `Cont.either`. Races this continuation against `right`, returning the first successful value.

- **Parameters:**
  - `right`: The other continuation to race with
  - `combine`: Function to combine error lists if both fail
  - `policy`: Execution policy determining how continuations are run

---

#### Cont.any

```dart
static Cont<E, A> any<E, A>(
  List<Cont<E, A>> list, {
  required ContPolicy<A> policy,
})
```

Races multiple continuations, returning the first successful value.

Executes all continuations in `list` and returns the first one that succeeds. If all fail, collects all errors. The execution behavior depends on the provided `policy`:

- **SequencePolicy**: Tries continuations one by one in order until one succeeds
- **MergeWhenAllPolicy**: Runs all in parallel, returns first success or merges results if all complete
- **QuitFastPolicy**: Runs all in parallel, returns immediately on first success

- **Parameters:**
  - `list`: List of continuations to race
  - `policy`: Execution policy determining how continuations are run

---

### Loop & Conditional Methods

#### when

```dart
Cont<E, A> when(bool Function(A value) predicate)
```

Conditionally succeeds only when the predicate is satisfied.

Filters the continuation based on the predicate. If the predicate returns `true`, the continuation succeeds with the value. If the predicate returns `false`, the continuation terminates without errors.

This is useful for conditional execution where you want to treat a predicate failure as termination rather than an error.

- **Parameters:**
  - `predicate`: Function that tests the value

**Example:**
```dart
final cont = Cont.of(42).when((n) => n > 0);
// Succeeds with 42

final cont2 = Cont.of(-5).when((n) => n > 0);
// Terminates
```

---

#### asLongAs

```dart
Cont<E, A> asLongAs(bool Function(A value) predicate)
```

Repeatedly executes the continuation as long as the predicate returns `true`, stopping when it returns `false`.

Runs the continuation in a loop, testing each result with the predicate. The loop continues as long as the predicate returns `true`, and stops successfully when the predicate returns `false`.

The loop is stack-safe and handles asynchronous continuations correctly. If the continuation terminates or if the predicate throws an exception, the loop stops and propagates the errors.

This is useful for retry logic, polling, or repeating an operation while a condition holds.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to continue looping, or `false` to stop and succeed with the value

**Example:**
```dart
// Poll an API while data is not ready
final result = fetchData().asLongAs((response) => !response.isReady);

// Retry while value is below threshold
final value = computation().asLongAs((n) => n < 100);
```

---

#### until

```dart
Cont<E, A> until(bool Function(A value) predicate)
```

Repeatedly executes the continuation until the predicate returns `true`.

Runs the continuation in a loop, testing each result with the predicate. The loop continues while the predicate returns `false`, and stops successfully when the predicate returns `true`.

This is the inverse of `asLongAs` - implemented as `asLongAs((a) => !predicate(a))`. Use this when you want to retry until a condition is met.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to stop the loop and succeed, or `false` to continue looping

**Example:**
```dart
// Retry until a condition is met
final result = fetchStatus().until((status) => status == 'complete');

// Poll until a threshold is reached
final value = checkProgress().until((progress) => progress >= 100);
```

---

#### forever

```dart
Cont<E, Never> forever()
```

Repeatedly executes the continuation indefinitely.

Runs the continuation in an infinite loop that never stops on its own. The loop only terminates if the underlying continuation terminates with an error.

The return type `Cont<E, Never>` indicates that this continuation never produces a value - it either runs forever or terminates with errors.

This is useful for:
- Daemon-like processes that run continuously
- Server loops that handle requests indefinitely
- Event loops that continuously process events
- Background tasks that should never stop

**Example:**
```dart
// A server that handles requests forever
final server = acceptConnection()
    .thenDo((conn) => handleConnection(conn))
    .forever();

// Run with only a termination handler (using trap extension)
server.trap(env, (errors) => print('Server stopped: $errors'));
```

---

### Resource Management

#### Cont.bracket

```dart
static Cont<E, A> bracket<E, R, A>({
  required Cont<E, R> acquire,
  required Cont<E, ()> Function(R resource) release,
  required Cont<E, A> Function(R resource) use,
})
```

Manages resource lifecycle with guaranteed cleanup.

The bracket pattern ensures that a resource is properly released after use, even if an error occurs during the `use` phase or if cancellation occurs. This is the functional equivalent of try-with-resources or using statements.

**The execution order is:**
1. `acquire` - Obtain the resource
2. `use` - Use the resource to produce a value
3. `release` - Release the resource (always runs, even if `use` fails or is cancelled)

**Cancellation behavior:**
- The `release` function is called even when the runtime is cancelled
- This ensures resources are properly cleaned up regardless of cancellation
- However, if cancellation occurs during release itself, cleanup may be partial

**Error handling behavior:**
- If `use` succeeds and `release` succeeds: returns the value from `use`
- If `use` succeeds and `release` fails: terminates with release errors
- If `use` fails and `release` succeeds: terminates with use errors
- If `use` fails and `release` fails: terminates with both errors combined

- **Parameters:**
  - `acquire`: Continuation that acquires the resource
  - `release`: Function that takes the resource and returns a continuation that releases it
  - `use`: Function that takes the resource and returns a continuation that uses it

**Example:**
```dart
final result = Cont.bracket<File, String>(
  acquire: openFile('data.txt'),           // acquire
  release: (file) => closeFile(file),      // release
  use: (file) => readContents(file),       // use
);
```

---

## Summary

The Jerelo library provides a comprehensive continuation monad system with:

- **Core abstractions**: `Cont`, `ContError`, `ContRuntime`, `ContObserver`
- **Execution policies**: Sequential, merge-when-all, and quit-fast strategies
- **Rich API**: 70+ methods for transformation, chaining, error handling, and parallel execution
- **Environment management**: Thread contextual information through computations
- **Resource safety**: Bracket pattern for guaranteed cleanup
- **Loop constructs**: Stack-safe looping with `asLongAs`, `until`, and `forever`
- **Type-safe**: Full Dart type safety with generic type parameters

All public APIs are documented with their behavior, parameters, and usage examples.
