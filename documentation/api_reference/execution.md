[Home](../../README.md) > API Reference > Execution & Extensions

# Execution & Extensions

Running continuations and specialized extensions.

---

## Table of Contents

- [ContCancelToken](#contcanceltoken)
- [Execution Methods](#execution-methods)
  - [run](#run)
  - [ff](#ff)
- [Extensions](#extensions)
  - [ContFlattenExtension](#contflattenextension)
  - [ContRunExtension](#contrunextension)
  - [ContAbsurdExtension](#contabsurdextension)

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

---

## Execution Methods

### run

```dart
ContCancelToken run(
  E env, {
  void Function(ContError fatal) onPanic = _panic,
  void Function(List<ContError> errors) onElse = _ignore,
  void Function(A value) onThen = _ignore,
})
```

Executes the continuation with separate callbacks for termination and value.

Initiates execution of the continuation with separate handlers for success and failure cases. All callbacks are optional and default to no-op, allowing callers to subscribe only to the channels they care about.

**Returns** a `ContCancelToken` that can be used to cooperatively cancel the execution. Calling `ContCancelToken.cancel()` sets an internal flag that the runtime polls via `isCancelled()`. The token also exposes `ContCancelToken.isCancelled()` to query the current cancellation state. Calling `cancel()` multiple times is safe but has no additional effect.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onPanic`: Callback invoked when a fatal, unrecoverable error occurs (e.g. an observer callback throws). Defaults to re-throwing inside a microtask
  - `onElse`: Callback invoked when the continuation terminates with errors. Defaults to ignoring the errors
  - `onThen`: Callback invoked when the continuation produces a successful value. Defaults to ignoring the value

**Example:**
```dart
// Subscribe to all channels and get a cancel token
final token = computation.run(
  env,
  onPanic: (fatal) => log('PANIC: ${fatal.error}'),
  onElse: (errors) => print('Failed: $errors'),
  onThen: (value) => print('Success: $value'),
);

// Subscribe only to the value channel
final token = computation.run(env, onThen: print);

// Cancel the computation when needed
token.cancel();

// Check cancellation state
print(token.isCancelled()); // true
```

---

### ff

```dart
void ff(
  E env, {
  void Function(ContError error) onPanic = _panic,
})
```

Executes the continuation in a fire-and-forget manner.

Runs the continuation without waiting for the result. Both success and failure outcomes are ignored. This is useful for side-effects that should run asynchronously without blocking or requiring error handling.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onPanic`: Callback invoked when a fatal, unrecoverable error occurs. Defaults to re-throwing inside a microtask

**Example:**
```dart
// Fire and forget a logging operation
logEvent(userId, action).ff(env);

// Continue with other work immediately
processNextRequest();
```

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

**Example:**
```dart
// Without flatten
final nested = Cont.of(Cont.of(42));
final result = nested.thenDo((inner) => inner);

// With flatten
final flattened = nested.flatten();
```

---

### ContRunExtension

```dart
extension ContRunExtension<E> on Cont<E, Never>
```

Extension for running continuations that never produce a value.

This extension provides specialized methods for `Cont<E, Never>` where only termination is expected, simplifying the API by removing the unused value callback.

**Methods:**

```dart
ContCancelToken trap(
  E env, {
  void Function(ContError error) onPanic = _panic,
  void Function(List<ContError> errors) onElse = _ignore,
})
```
Executes the continuation expecting only termination. This is a convenience method for `Cont<E, Never>` that executes the continuation with only a termination handler, since a value callback would never be called for a `Cont<E, Never>`. All callbacks are optional and default to no-op.

**Returns** a `ContCancelToken` that can be used to cooperatively cancel the execution. Calling `ContCancelToken.cancel()` sets an internal flag that the runtime polls via `isCancelled()`. The token also exposes `ContCancelToken.isCancelled()` to query the current cancellation state.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onPanic`: Callback invoked when a fatal, unrecoverable error occurs. Defaults to re-throwing inside a microtask
  - `onElse`: Callback invoked when the continuation terminates with errors. Defaults to ignoring the errors

**Example:**
```dart
final cont = Cont.stop<MyEnv, Never>([ContError.capture(Exception('Failed'))]);
final token = cont.trap(myEnv, onElse: (errors) {
  print('Terminated with ${errors.length} error(s)');
});

// Cancel the continuation when needed
token.cancel();

// Check cancellation state
print(token.isCancelled()); // true
```

---

### ContAbsurdExtension

```dart
extension ContAbsurdExtension<E> on Cont<E, Never>
```

Extension providing type conversion for continuations that never produce a value.

**Methods:**

```dart
Cont<E, A> absurd<A>()
```

Converts a continuation that never produces a value to any desired type.

The `absurd` method implements the principle of "ex falso quodlibet" (from falsehood, anything follows) from type theory. It allows converting a `Cont<E, Never>` to `Cont<E, A>` for any type `A`.

Since `Never` is an uninhabited type with no possible values, the mapping function `(Never never) => never` can never actually execute. However, the type system accepts this transformation as valid, enabling type-safe conversion from a continuation that cannot produce a value to one with any desired value type.

This is particularly useful when:
- Working with continuations that run forever (e.g., from `forever`)
- Matching types with other continuations in composition
- Converting terminating-only continuations to typed continuations

- **Type Parameters:**
  - `A`: The desired value type for the resulting continuation

**Returns:** A continuation with the same environment type but a different value type parameter.

**Example:**
```dart
// A server that runs forever has type Cont<Env, Never>
final server = handleRequests().forever();

// Convert to Cont<Env, String> to match other continuation types
final serverAsString = server.absurd<String>();

// Now it can be used in contexts expecting Cont<Env, String>
final result = Cont.either(
  serverAsString,
  fallbackOperation,
  policy: ContEitherPolicy.quitFast(),
);
```
