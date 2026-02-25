[Home](../../README.md) > API Reference > Execution & Extensions

# Execution & Extensions

Running continuations and specialized extensions.

---

## Table of Contents

- [Execution Methods](#execution-methods)
  - [run](#run)
  - [runWith](#runwith)
- [Extensions](#extensions)
  - [flatten](#flatten)
  - [absurdify](#absurdify)
  - [thenAbsurdify](#thenabsurdify)
  - [elseAbsurdify](#elseabsurdify)
  - [thenAbsurd](#thenabsurd)
  - [elseAbsurd](#elseabsurd)

---

## Execution Methods

### run

```dart
ContCancelToken run(
  E env, {
  void Function(NormalCrash crash) onPanic,
  void Function(ContCrash crash) onCrash,
  void Function(F error) onElse,
  void Function(A value) onThen,
})
```

Executes the continuation with separate callbacks for each outcome channel.

Initiates execution of the continuation with separate handlers for panics, crashes, errors, and successes. All callbacks are optional and default to no-op (except `onPanic` which defaults to re-throwing inside a microtask), allowing callers to subscribe only to the channels they care about.

**Returns** a `ContCancelToken` that can be used to cooperatively cancel the execution.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onPanic`: Callback invoked when a fatal, unrecoverable panic occurs (e.g., an observer callback throws). Defaults to re-throwing inside a microtask
  - `onCrash`: Callback invoked when the continuation crashes with an unexpected exception. Defaults to ignoring the crash
  - `onElse`: Callback invoked when the continuation terminates with a typed error. Defaults to ignoring the error
  - `onThen`: Callback invoked when the continuation produces a successful value. Defaults to ignoring the value

**Example:**
```dart
// Subscribe to all channels
final token = computation.run(
  env,
  onPanic: (panic) => log('PANIC: ${panic.error}'),
  onCrash: (crash) => log('Crash: $crash'),
  onElse: (error) => print('Failed: $error'),
  onThen: (value) => print('Success: $value'),
);

// Subscribe only to the value channel
computation.run(env, onThen: print);

// Cancel the computation when needed
token.cancel();
```

---

### runWith

```dart
void runWith(
  ContRuntime<E> runtime,
  ContObserver<F, A> observer,
)
```

Low-level execution method that runs the continuation with an explicit runtime and observer.

This is the primitive execution method used internally by the library. It gives full control over the runtime context and observer callbacks. Most users should prefer `run` instead.

- **Parameters:**
  - `runtime`: The runtime context providing environment and cancellation
  - `observer`: The observer that receives crash, error, and success callbacks

---

## Extensions

### flatten

```dart
extension ContFlattenExtension<E, F, A> on Cont<E, F, Cont<E, F, A>>
```

Extension providing flatten operation for nested continuations.

```dart
Cont<E, F, A> flatten()
```
Flattens a nested `Cont` structure. Converts `Cont<E, F, Cont<E, F, A>>` to `Cont<E, F, A>`. Equivalent to `thenDo((contA) => contA)`.

**Example:**
```dart
// Without flatten
final nested = Cont.of<(), Never, Cont<(), Never, int>>(Cont.of(42));
final result = nested.thenDo((inner) => inner);

// With flatten
final flattened = nested.flatten();
```

---

### absurdify

```dart
extension ContAbsurdifyExtension<E, F, A> on Cont<E, F, A>
```

```dart
Cont<E, F, A> absurdify()
```

Widens both `Never` channels simultaneously. If `F` is `Never`, it widens the error channel; if `A` is `Never`, it widens the success channel. Equivalent to calling `thenAbsurdify()` and `elseAbsurdify()`.

This is safe because `Never` is uninhabited — a callback for `Never` can never actually be invoked.

**Example:**
```dart
final neverBoth = Cont.crash<(), Never, Never>(someCrash);
final Cont<(), String, int> widened = neverBoth.absurdify();
```

---

### thenAbsurdify

```dart
Cont<E, F, A> thenAbsurdify()
```

Widens the success channel when `A` is `Never`. Since a `Never` callback can never be invoked, this is a safe type-level transformation.

**Example:**
```dart
final Cont<(), String, Never> neverSucceeds = Cont.error('fail');
final Cont<(), String, int> widened = neverSucceeds.thenAbsurdify();
```

---

### elseAbsurdify

```dart
Cont<E, F, A> elseAbsurdify()
```

Widens the error channel when `F` is `Never`. Since a `Never` callback can never be invoked, this is a safe type-level transformation.

**Example:**
```dart
final Cont<(), Never, int> neverFails = Cont.of(42);
final Cont<(), String, int> widened = neverFails.elseAbsurdify();
```

---

### thenAbsurd

```dart
extension ContThenNeverExtension<E, F> on Cont<E, F, Never>
```

```dart
Cont<E, F, A> thenAbsurd<A>()
```

Converts a continuation that never produces a value to any desired value type.

Implements the principle of "ex falso quodlibet" (from falsehood, anything follows). Since `Never` is uninhabited, the success callback can never be called, making this a safe type-level transformation.

This is useful when:
- Working with continuations that run forever (e.g., from `thenForever`)
- Matching types with other continuations in composition
- Converting terminating-only continuations to typed continuations

- **Type Parameters:**
  - `A`: The desired value type for the resulting continuation

**Example:**
```dart
// A server that runs forever has type Cont<Env, String, Never>
final server = handleRequests().thenForever();

// Convert to Cont<Env, String, int> to match other continuation types
final serverAsInt = server.thenAbsurd<int>();
```

---

### elseAbsurd

```dart
extension ContElseNeverExtension<E, A> on Cont<E, Never, A>
```

```dart
Cont<E, F, A> elseAbsurd<F>()
```

Converts a continuation that never produces an error to any desired error type.

The error-channel counterpart of `thenAbsurd`. Since `Never` is uninhabited, the error callback can never be called, making this a safe type-level transformation.

- **Type Parameters:**
  - `F`: The desired error type for the resulting continuation

**Example:**
```dart
// A continuation that cannot fail
final infallible = Cont.of<(), Never, int>(42);

// Convert to match a context expecting String errors
final Cont<(), String, int> compatible = infallible.elseAbsurd<String>();
```
