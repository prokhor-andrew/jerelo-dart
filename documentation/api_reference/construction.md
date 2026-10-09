[Home](../../README.md) > API Reference > Construction & Decorating

# Construction & Decorating

Creating and transforming continuations.

---

## Table of Contents

- [Constructors](#constructors)
  - [Cont.fromRun](#contfromrun)
  - [Cont.fromDeferred](#contfromdeferred)
  - [Cont.of](#contof)
  - [Cont.error](#conterror)
  - [Cont.crash](#contcrash)
  - [Cont.askThen](#contaskthen)
  - [Cont.askElse](#contaskelse)
  - [Cont.bracket](#contbracket)
- [Transformation](#transformation)
  - [decorate](#decorate)

---

## Constructors

### Cont.fromRun

```dart
static Cont<E, F, A> fromRun<E, F, A>(
  void Function(ContRuntime<E> runtime, SafeObserver<F, A> observer) run,
)
```

Creates a `Cont` from a run function that accepts an observer.

Constructs a continuation with guaranteed idempotence and exception catching. The run function receives a `SafeObserver` with `onCrash`, `onElse`, and `onThen` callbacks. The callbacks should be called as the last instruction in the run function or saved to be called later. The `SafeObserver` ensures that only the first callback invocation takes effect; subsequent calls are ignored. This guard covers only the observer handed to `run`: observers derived from it with `copyUpdate*` call their new callbacks every time.

Exceptions thrown synchronously by `run` are caught and routed to the crash channel. An exception thrown later, for example inside a `Timer` or `Future` callback, is not caught: it escapes to the zone and the observer is never called. Wrap such callback bodies in `ContCrash.tryCatch` and pass the crash to `observer.onCrash`.

- **Parameters:**
  - `run`: Function that executes the continuation and calls observer callbacks

**Example:**
```dart
final cont = Cont.fromRun<MyEnv, String, int>((runtime, observer) {
  // Access environment
  final config = runtime.env();

  // Check cancellation: a cancelled computation emits nothing
  if (runtime.isCancelled()) {
    return;
  }

  // Produce a value
  observer.onThen(42);
});
```

---

### Cont.fromDeferred

```dart
static Cont<E, F, A> fromDeferred<E, F, A>(Cont<E, F, A> Function() thunk)
```

Creates a `Cont` from a deferred continuation computation.

Lazily evaluates a continuation-returning function. The inner `Cont` is not created until the outer one is executed.

- **Parameters:**
  - `thunk`: Function that returns a `Cont` when called

**Example:**
```dart
// The inner continuation is not created until execution
final deferred = Cont.fromDeferred(() {
  print('Creating continuation...');
  return Cont.of(42);
});

// Prints "Creating continuation..." when run
deferred.run((), onThen: print);
```

---

### Cont.of

```dart
static Cont<E, F, A> of<E, F, A>(A value)
```

Creates a `Cont` that immediately succeeds with a value.

Identity operation that wraps a pure value in a continuation context.

- **Parameters:**
  - `value`: The value to wrap

**Example:**
```dart
final cont = Cont.of(42);
cont.run((), onThen: print); // prints: 42
```

---

### Cont.error

```dart
static Cont<E, F, A> error<E, F, A>(F err)
```

Creates a `Cont` that immediately terminates with a typed error.

Creates a continuation that terminates without producing a value. Used to represent typed failure states.

- **Parameters:**
  - `err`: The error value to terminate with

**Example:**
```dart
final cont = Cont.error('Not found');

cont.run((), onElse: (error) {
  print('Failed: $error'); // prints: Failed: Not found
});
```

---

### Cont.crash

```dart
static Cont<E, F, A> crash<E, F, A>(ContCrash crash)
```

Creates a `Cont` that immediately crashes with an unexpected exception.

Used to represent unrecoverable failures that are outside the typed error channel.

- **Parameters:**
  - `crash`: The crash to propagate

**Example:**
```dart
final cont = Cont.fromDeferred(() {
  throw Exception('Unexpected failure');
}).crashDo((crash) {
  if (crash is! NormalCrash) {
    return Cont.of(0);
  }
  return Cont.crash(crash);
});

cont.run((), onCrash: (crash) {
  print('Crashed: $crash');
});
```

---

### Cont.askThen

```dart
static Cont<E, F, E> askThen<E, F>()
```

Retrieves the current environment value as a success.

Accesses the environment of type `E` from the runtime context and places it on the then (success) channel. This is used to read configuration, dependencies, or any contextual information that flows through the continuation execution.

Returns a continuation that succeeds with the environment value.

**Example:**
```dart
final cont = Cont.askThen<DatabaseConfig, String>()
  .thenDo((config) => queryDatabase(config.connectionString));
```

---

### Cont.askElse

```dart
static Cont<E, E, A> askElse<E, A>()
```

Retrieves the current environment value as an error.

Accesses the environment of type `E` from the runtime context and places it on the else (error) channel. This is the error-channel counterpart of `askThen`.

Returns a continuation that terminates with the environment value as the error.

**Example:**
```dart
final cont = Cont.askElse<String, int>()
  .elseDo((errorMsg) => logAndRecover(errorMsg));
```

---

### Cont.bracket

```dart
static Cont<E, F, A> bracket<R, E, F, A>({
  required Cont<E, Never, R> acquire,
  required Cont<E, Never, ()> Function(R resource) release,
  required Cont<E, F, A> Function(R resource) use,
  void Function(NormalCrash crash) onReleasePanic,
  void Function(ContCrash crash) onReleaseCrash,
  void Function() onReleaseThen,
})
```

Manages resource lifecycle with guaranteed cleanup.

The bracket pattern ensures that a resource is properly released after use, even if an error or crash occurs during the `use` phase or if cancellation occurs. This is the functional equivalent of try-with-resources or using statements.

Note that `acquire` and `release` use `Never` as their error type, meaning they cannot fail with a typed error — they can only succeed or crash.

**The execution order is:**
1. `acquire` — Obtain the resource
2. `use` — Use the resource to produce a value
3. `release` — Release the resource (always runs if `acquire` succeeded, even if `use` fails or is cancelled)

**Cancellation behavior:**
- `acquire` always runs to completion, so an acquired resource is never lost
- If the computation is cancelled before `use` starts, `release` runs as soon as `acquire` completes and nothing is emitted
- If the computation is cancelled while `use` runs, `release` runs immediately, without waiting for `use`. `use` may then fail on the released resource; its outcome is dropped
- `release` runs at most once, on a runtime that is never cancelled

**Optional release callbacks:**
- `onReleasePanic`: Called if the `release` function itself throws while building the release continuation (`release(resource)`), or if a release callback throws. Defaults to re-throwing in a microtask, so a `try`/`catch` around `run()` never sees it
- `onReleaseCrash`: Called if the release continuation returned by `release` crashes. Defaults to ignoring
- `onReleaseThen`: Called when release succeeds. Defaults to no-op

- **Parameters:**
  - `acquire`: Continuation that acquires the resource (cannot fail with typed error)
  - `release`: Function that takes the resource and returns a continuation that releases it (cannot fail with typed error)
  - `use`: Function that takes the resource and returns a continuation that uses it
  - `onReleasePanic`: Optional panic handler for release phase
  - `onReleaseCrash`: Optional crash handler for release phase
  - `onReleaseThen`: Optional success handler for release phase

**Example:**
```dart
final result = Cont.bracket<File, MyEnv, String, String>(
  acquire: openFile('data.txt'),
  release: (file) => closeFile(file),
  use: (file) => readContents(file),
);
```

---

## Transformation

### decorate

```dart
Cont<E, F, A> decorate(
  void Function(
    void Function(ContRuntime<E>, ContObserver<F, A>) run,
    ContRuntime<E> runtime,
    ContObserver<F, A> observer,
  ) f,
)
```

Transforms the execution of the continuation using a natural transformation.

Applies a function that wraps or modifies the underlying run behavior. This is useful for intercepting execution to add middleware-like behavior such as logging, timing, or modifying how observers receive callbacks.

The transformation function receives the original run function, the runtime, and the observer, allowing custom execution behavior to be injected.

- **Parameters:**
  - `f`: A transformation function that receives the run function, runtime, and observer, and implements custom execution logic by calling the run function at the appropriate time

**Example:**
```dart
// Add logging around execution
final logged = cont.decorate((run, runtime, observer) {
  print('Starting execution');
  run(runtime, observer);
  print('Execution initiated');
});

// Add timing
final timed = cont.decorate((run, runtime, observer) {
  final start = DateTime.now();
  run(
    runtime,
    observer.copyUpdateOnThen((value) {
      final duration = DateTime.now().difference(start);
      print('Took $duration');
      observer.onThen(value);
    }),
  );
});
```
