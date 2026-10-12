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
- [Transformation](#transformation)
  - [decorate](#decorate)
- [More in jerelo_ext](#more-in-jerelo_ext)

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

  // Produce a value
  observer.onThen(config.port);
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

Used to represent unrecoverable failures that are outside the typed error channel.

- **Parameters:**
  - `crash`: The crash to propagate

**Example:**
```dart
final cont = Cont.fromRun<(), String, int>((runtime, observer) {
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

---

## More in jerelo_ext

`contDeferred`, which builds the continuation lazily when it runs, and `contBracket`, which acquires, uses and releases a resource, are top-level functions in the [jerelo_ext](https://pub.dev/packages/jerelo_ext) package; import `package:jerelo_ext/jerelo_ext.dart` alongside `package:jerelo/jerelo.dart`.
