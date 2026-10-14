[Home](../../README.md) > API Reference > Execution & Extensions

# Execution & Extensions

Running continuations and specialized extensions.

---

## Table of Contents

- [Execution Methods](#execution-methods)
  - [run](#run)
  - [runWith](#runwith)
- [Cancellation](#cancellation)
  - [ContCancelToken](#contcanceltoken)
  - [How a cancel travels](#how-a-cancel-travels)
  - [Limitations](#limitations)
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

- **Parameters:**
  - `env`: The environment value to provide as context during execution
  - `onPanic`: Callback invoked when a fatal, unrecoverable panic occurs (e.g., an observer callback throws). Defaults to re-throwing inside a microtask
  - `onCrash`: Callback invoked when the continuation crashes with an unexpected exception. Defaults to ignoring the crash
  - `onElse`: Callback invoked when the continuation terminates with a typed error. Defaults to ignoring the error
  - `onThen`: Callback invoked when the continuation produces a successful value. Defaults to ignoring the value
- **Returns:** A [`ContCancelToken`](#contcanceltoken) that cancels the computation. See [Cancellation](#cancellation).

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

// Keep the token to cancel the computation later
final token = computation.run(env, onThen: print);
token.cancel();
```

---

### runWith

```dart
void Function() runWith(
  E env,
  ContObserver<F, A> observer,
)
```

Low-level execution method that runs the continuation with an explicit environment and observer.

This is the primitive execution method used internally by the library. It gives full control over the environment and observer callbacks. Most users should prefer `run` instead. It is useful inside `Cont.fromRun` and `decorate`, where an environment and an observer are already at hand.

- **Parameters:**
  - `env`: The environment to run the continuation with
  - `observer`: The observer that receives crash, error, and success callbacks
- **Returns:** The canceller of the computation it starts. Inside `Cont.fromRun` or `decorate`, return it so that a cancel reaches the inner computation.

**Example:**
```dart
Cont<E, F, A> deferred<E, F, A>(Cont<E, F, A> Function() build) {
  return Cont.fromRun((env, observer) {
    return build().runWith(env, observer);
  });
}
```

---

## Cancellation

A running computation is cancelled through the token returned by `run`. A cancel carries no value and has no channel of its own: the operators only pass it on, and the leaves — the computations built with `Cont.fromRun` — decide what cancelling means and how to report it.

```dart
final token = download(url).run(
  env,
  onElse: (error) => print('Stopped: $error'),
  onThen: (file) => print('Saved $file'),
);

// Later, e.g. when the user leaves the screen
token.cancel();
```

What happens next depends on the leaf that is running. A leaf with a real canceller, such as a timer or an HTTP request, stops its work and reports through one of the existing channels, usually `onElse` with an error type of your own. A leaf whose canceller is a no-op simply finishes normally. Either way, the outcome arrives through the callbacks passed to `run`. See [Extending Jerelo](../user_guide/06-extending.md#cancellation) for writing cancellable leaves.

### ContCancelToken

```dart
final class ContCancelToken
```

Returned by `run`. It has a private constructor.

```dart
void cancel()
```

Cancels the computation. Only the first call has an effect; later calls do nothing.

```dart
bool isCancelled()
```

Returns `true` if `cancel` has been called on this token. It does **not** tell whether the computation has stopped: the computation reports how it ended through the callbacks passed to `run`.

### How a cancel travels

The canceller returned by `Cont.fromRun` is the only place where a cancel does anything. Every operator forwards it:

- **To the part running now, and to every part started afterwards.** In `a.thenDo(f)`, a cancel reaches `a` while it runs. If `a` still reports a value after the cancel, `f` is called, and the computation it returns starts and is cancelled immediately.
- **Combinators** forward a cancel to every branch that is running.
- **`quitFast` policies** (`both`, `either`, `all`, `any`, `coalesce`, `converge` and their instance forms): once the result is decided, the inputs still running are cancelled.
- **`runAll` policies** never cancel on their own; a cancel from outside is forwarded to every running input.
- **`sequence` policies** cancel the input that is running and every later input as it starts.
- **Loops** (the `*While` and `*Until` operators) forward a cancel to the running iteration and start no iteration after it. The loop ends with the outcome of the iteration that was running, once it reports.
- **`Cont.bracket`** forwards a cancel to `use` only. `acquire` and `release` are never cancelled; a cancel that arrives while `acquire` runs is applied to `use` as soon as it starts. `release` runs once `use` reports back, on any channel.
- **Forks** (`thenFork`, `elseFork`, `crashFork` and their variants): the forked side effect is detached and is **not** cancelled with the parent. The main computation is.

A leaf's canceller runs at most once, and never after the leaf has finished. If the canceller throws, the leaf crashes; if the leaf has already finished, the throw becomes a panic.

### Limitations

Cancellation is only as good as the leaves:

- A leaf that ignores cancellation runs until it finishes. For example, a request whose canceller is `() {}` still completes, and the computation reports its outcome only then.
- Your code can still run after a cancel. When a stage reports a value after the cancel, the function of the next operator (for example the function passed to `thenDo`) is still called; only the computation it returns is cancelled.
- A cancelled computation reports an outcome like any other, or none at all if its leaf reports nothing. Use the callbacks passed to `run`, not `isCancelled`, to learn how it ended.

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
- Working with continuations that never succeed, such as one that always ends on the else or crash channel
- Matching types with other continuations in composition
- Converting terminating-only continuations to typed continuations

- **Type Parameters:**
  - `A`: The desired value type for the resulting continuation

**Example:**
```dart
// A computation that can only fail has type Cont<Env, String, Never>
final Cont<Env, String, Never> notFound = Cont.error('not found');

// Convert to Cont<Env, String, int> to match other continuation types
final notFoundAsInt = notFound.thenAbsurd<int>();
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
