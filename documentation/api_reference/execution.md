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
  - [thenAbsurd](#thenabsurd)
  - [elseAbsurd](#elseabsurd)
  - [thenUnit](#thenunit)
  - [elseUnit](#elseunit)

---

## Execution Methods

### run

```dart
void run(
  E env, {
  void Function(NormalCrash crash) onPanic,
  void Function(ContCrash crash) onCrash,
  void Function(F error) onElse,
  void Function(A value) onThen,
})
```

Executes the continuation with separate callbacks for each outcome channel.

Initiates execution of the continuation with separate handlers for panics, crashes, errors, and successes. All callbacks are optional and default to no-op (except `onPanic` which defaults to re-throwing inside a microtask), allowing callers to subscribe only to the channels they care about.

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onPanic`: Callback invoked when a fatal, unrecoverable panic occurs (e.g., an observer callback throws). Defaults to re-throwing inside a microtask
  - `onCrash`: Callback invoked when the continuation crashes with an unexpected exception. Defaults to ignoring the crash
  - `onElse`: Callback invoked when the continuation terminates with a typed error. Defaults to ignoring the error
  - `onThen`: Callback invoked when the continuation produces a successful value. Defaults to ignoring the value

**Example:**
```dart
// Subscribe to all channels
computation.run(
  (),
  onPanic: (panic) => log('PANIC: ${panic.error}'),
  onCrash: (crash) => log('Crash: $crash'),
  onElse: (error) => print('Failed: $error'),
  onThen: (value) => print('Success: $value'),
);

// Subscribe only to the value channel
computation.run(env, onThen: print);
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
  - `runtime`: The runtime context providing the environment
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
- Working with continuations that never succeed, such as a loop that only ends on the else or crash channel
- Matching types with other continuations in composition
- Converting terminating-only continuations to typed continuations

- **Type Parameters:**
  - `A`: The desired value type for the resulting continuation

**Example:**
```dart
// A server loop that only ends with an error has type Cont<Env, String, Never>
final Cont<Env, String, Never> server = Cont.tailRecM(
  (),
  (_) => handleRequest().thenMap((_) => const TailRec.next(())),
);

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

---

### thenUnit

```dart
extension ContUnitExtension<E, F, A> on Cont<E, F, A>
```

```dart
Cont<E, F, ()> thenUnit()
```

Replaces the success value with `()`.

Use it when only the fact that the continuation succeeded matters. The unit type `()` is the terminal object: every type has exactly one function into it. This makes `thenUnit` the dual of `thenAbsurd`.

**Example:**
```dart
final Cont<(), String, ()> saved = saveUser(user).thenUnit();
```

---

### elseUnit

```dart
Cont<E, (), A> elseUnit()
```

Replaces the error with `()`.

Use it when only the fact that the continuation failed matters. The error-channel counterpart of `thenUnit`, and the dual of `elseAbsurd`.

**Example:**
```dart
final Cont<(), (), User> user = fetchUser(userId).elseUnit();
```
