[Home](../../README.md) > API Reference > Construction & Decorating

# Construction & Decorating

Creating and transforming continuations.

---

## Table of Contents

- [Constructors](#constructors)
  - [Cont.fromRun](#contfromrun)
  - [Cont.of](#contof)
  - [Cont.error](#conterror)
  - [Cont.crash](#contcrash)
  - [Cont.askThen](#contaskthen)
  - [Cont.askElse](#contaskelse)
  - [Cont.fromDeferred](#contfromdeferred)
  - [Cont.bracket](#contbracket)
- [Transformation](#transformation)
  - [decorate](#decorate)

---

## Constructors

### Cont.fromRun

```dart
static Cont<E, F, A> fromRun<E, F, A>(
  void Function() Function(E env, SafeObserver<F, A> observer) run,
)
```

Creates a `Cont` from a run function that accepts an observer.

Constructs a continuation with guaranteed idempotence and exception catching. The run function receives a `SafeObserver` with `onCrash`, `onElse`, and `onThen` callbacks. The callbacks should be called as the last instruction in the run function or saved to be called later. The `SafeObserver` ensures that only the first callback invocation takes effect; subsequent calls are ignored. This guard covers only the observer handed to `run`: observers derived from it with `copyUpdate*` call their new callbacks every time.

Exceptions thrown synchronously by `run` are caught. One thrown before the observer was called crashes the computation; one thrown after it becomes a panic, and the outcome already reported stands. An exception thrown later, for example inside a `Timer` or `Future` callback, is not caught: it escapes to the zone and the observer is never called. Wrap such callback bodies in `ContCrash.tryCatch` and pass the crash to `observer.onCrash`.

The run function returns a **canceller**: the function that runs when the computation is cancelled (see [Cancellation](execution.md#cancellation)). The canceller decides what cancelling means and reports the outcome through the observer, for example by stopping a timer and calling `observer.onElse`. A computation that cannot be cancelled returns a no-op `() {}`, and simply finishes normally when cancelled. The canceller runs at most once, and never after the computation has reported an outcome. If it throws, the computation crashes; if the computation has already finished, the throw becomes a panic.

- **Parameters:**
  - `run`: Function that executes the continuation, calls observer callbacks, and returns a canceller

**Example:**
```dart
final cont = Cont.fromRun<MyEnv, String, int>((env, observer) {
  // Produce a value from the environment
  observer.onThen(env.port);
  return () {};
});

// A cancellable computation: cancelling stops the timer
// and reports on the else channel
final delayed = Cont.fromRun<(), String, int>((env, observer) {
  final timer = Timer(const Duration(seconds: 1), () {
    observer.onThen(42);
  });
  return () {
    timer.cancel();
    observer.onElse('cancelled');
  };
});
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

Used to represent unexpected failures that are outside the typed error channel.

- **Parameters:**
  - `crash`: The crash to propagate

**Example:**
```dart
final cont = Cont.fromRun<(), String, int>((env, observer) {
  throw FormatException('Unexpected input');
}).crashDo((crash) {
  // Recover from format errors, keep every other crash
  if (crash case NormalCrash(error: FormatException())) {
    return Cont.of(0);
  }
  return Cont.crash(crash);
});

cont.run(
  (),
  onCrash: (crash) => print('Crashed: $crash'),
  onThen: print, // prints: 0
);
```

---

### Cont.askThen

```dart
static Cont<E, F, E> askThen<E, F>()
```

Retrieves the current environment value as a success.

Accesses the environment of type `E` the continuation runs with and places it on the then (success) channel. This is used to read configuration, dependencies, or any contextual information that flows through the continuation execution.

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

Accesses the environment of type `E` the continuation runs with and places it on the else (error) channel. This is the error-channel counterpart of `askThen`.

Returns a continuation that terminates with the environment value as the error.

**Example:**
```dart
final cont = Cont.askElse<String, int>()
  .elseDo((errorMsg) => logAndRecover(errorMsg));
```

---

### Cont.fromDeferred

```dart
static Cont<E, F, A> fromDeferred<E, F, A>(
  Cont<E, F, A> Function() thunk,
)
```

Creates a `Cont` whose continuation is built only when it runs.

Lazily evaluates a continuation-returning function. The inner `Cont` is not created until the outer one is executed, and `thunk` is called on every run, so each run gets a freshly built continuation. Use it to delay expensive construction or to create per-run state. A throw from `thunk` becomes a crash. A cancel is forwarded to the built continuation.

- **Parameters:**
  - `thunk`: Function that returns a `Cont` when called

**Example:**
```dart
// The inner continuation is not created until execution
final deferred = Cont.fromDeferred(() {
  print('Creating continuation...');
  return Cont.of<(), Never, int>(42);
});

// Prints "Creating continuation..." when run
deferred.run((), onThen: print);
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

Manages a resource lifecycle with cleanup after use.

The bracket pattern releases a resource once it has been used, whether `use` succeeds, terminates with an error, or crashes. This is the functional equivalent of try-with-resources or using statements.

Note that `acquire` and `release` use `Never` as their error type, meaning they cannot fail with a typed error — they can only succeed or crash.

**The execution order is:**
1. `acquire` — Obtain the resource. If it crashes, the crash is forwarded and nothing else runs
2. `use` — Use the resource to produce a value. A throw from `use` itself becomes a crash
3. `release` — Release the resource. Runs once `use` reports any outcome (success, error or crash), after that outcome is forwarded

`release` is fire-and-forget: the outcome of `use` is forwarded first and does not wait for `release`. Release outcomes go to the optional release callbacks instead.

**Cancellation:** a cancel is forwarded to `use` only. `acquire` and `release` are never cancelled. A cancel that arrives while `acquire` runs is applied to `use` as soon as it starts. There is no special cancel path: `release` runs once `use` reports back, on any channel; if `use` never reports, `release` never runs.

**Optional release callbacks:**
- `onReleasePanic`: Called if the `release` function itself throws while building the release continuation (`release(resource)`), or if a release callback throws. Defaults to rethrowing in a microtask, so a `try`/`catch` around `run()` never sees it
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
  onReleaseCrash: (crash) => print('Failed to close: $crash'),
);
```

---

## Transformation

### decorate

```dart
Cont<E, F, A> decorate(
  void Function() Function(
    void Function() Function(E, ContObserver<F, A>) run,
    E env,
    ContObserver<F, A> observer,
  ) f,
)
```

Transforms the execution of the continuation using a natural transformation.

Applies a function that wraps or modifies the underlying run behavior. This is useful for intercepting execution to add middleware-like behavior such as logging, timing, or modifying how observers receive callbacks.

The transformation function receives the original run function, the environment, and the observer, allowing custom execution behavior to be injected. It returns the canceller of the run it started, which is usually the value the run function returned.

- **Parameters:**
  - `f`: A transformation function that receives the run function, environment, and observer, implements custom execution logic by calling the run function at the appropriate time, and returns a canceller

**Example:**
```dart
// Add logging around execution
final logged = cont.decorate((run, env, observer) {
  print('Starting execution');
  final cancel = run(env, observer);
  print('Execution initiated');
  return cancel;
});

// Add timing
final timed = cont.decorate((run, env, observer) {
  final start = DateTime.now();
  return run(
    env,
    observer.copyUpdateOnThen((value) {
      final duration = DateTime.now().difference(start);
      print('Took $duration');
      observer.onThen(value);
    }),
  );
});
```
