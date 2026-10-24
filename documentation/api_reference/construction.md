[Home](../../README.md) > API Reference > Construction & Decorating

# Construction & Decorating

Creating and transforming continuations.

---

## Table of Contents

- [Constructors](#constructors)
  - [Cont.fromRun](#contfromrun)
  - [Cont.fromDeferred](#contfromdeferred)
  - [Cont.of](#contof)
  - [Cont.stop](#contstop)
  - [Cont.ask](#contask)
  - [Cont.askThen](#contaskthen)
  - [Cont.bracket](#contbracket)
- [Transformation](#transformation)
  - [decor](#decor)

---

## Constructors

### Cont.fromRun

```dart
static Cont<E, A> fromRun<E, A>(void Function(ContRuntime<E> runtime, ContObserver<A> observer) run)
```

Creates a `Cont` from a run function that accepts an observer.

Constructs a continuation with guaranteed idempotence. If `run` throws synchronously, the error is caught and the continuation terminates with it. A throw in a callback that runs later, such as a `Timer` or `Future` callback, is not caught: it escapes as an unhandled exception and the observer is never called, so catch errors there yourself and pass them to `onElse`. The run function receives an observer with `onThen` and `onElse` callbacks. The callbacks should be called as the last instruction in the run function or saved to be called later. A callback called while the run function is still running only records the outcome: the next stage starts after the run function returns, so code after the call runs first. A callback called later, for example from a timer, runs the next stages before it returns.

- **Parameters:**
  - `run`: Function that executes the continuation and calls observer callbacks

**Example:**
```dart
final cont = Cont.fromRun<MyEnv, int>((runtime, observer) {
  // Access environment
  final config = runtime.env();

  Timer(config.timeout, () {
    // Check cancellation. Results delivered after cancellation
    // are dropped, so there is nothing to report: just return.
    if (runtime.isCancelled()) {
      return;
    }

    // Produce a value
    observer.onThen(42);
  });
});
```

---

### Cont.fromDeferred

```dart
static Cont<E, A> fromDeferred<E, A>(Cont<E, A> Function() thunk)
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
deferred.run(env, onThen: print);
```

---

### Cont.of

```dart
static Cont<E, A> of<E, A>(A value)
```

Creates a `Cont` that immediately succeeds with a value.

Identity operation that wraps a pure value in a continuation context.

- **Parameters:**
  - `value`: The value to wrap

**Example:**
```dart
final cont = Cont.of<(), int>(42);
cont.run((), onThen: print); // prints: 42
```

---

### Cont.stop

```dart
static Cont<E, A> stop<E, A>([List<ContError> errors = const []])
```

Creates a `Cont` that immediately terminates with optional errors.

Creates a continuation that terminates without producing a value. Used to represent failure states.

- **Parameters:**
  - `errors`: List of errors to terminate with. Defaults to an empty list

**Example:**
```dart
final cont = Cont.stop<(), int>([
  ContError.capture('Not found'),
]);

cont.run((), onElse: (errors) {
  print('Failed: ${errors.first.error}');
});
```

---

### Cont.ask

```dart
static Cont<E, E> ask<E>()
```

Retrieves the current environment value.

Accesses the environment of type `E` from the runtime context. This is used to read configuration, dependencies, or any contextual information that flows through the continuation execution.

Returns a continuation that succeeds with the environment value.

**Example:**
```dart
final cont = Cont.ask<DatabaseConfig>().thenDo((config) {
  return queryDatabase(config.connectionString);
});
```

---

### Cont.askThen

```dart
static Cont<E, A> askThen<E, A>(Cont<E, A> Function(E env) f)
```

Retrieves the environment and chains a computation that depends on it.

Convenience method equivalent to `Cont.ask<E>().thenDo(f)`. Reads the environment of type `E` and immediately passes it to `f`, which returns a continuation to execute next.

This is the most common pattern when building computations that depend on the environment, avoiding the need to manually call `ask` and `thenDo` separately.

- **Parameters:**
  - `f`: Function that takes the environment and returns a continuation

**Example:**
```dart
final cont = Cont.askThen<DatabaseConfig, List<User>>((config) {
  return queryDatabase(config.connectionString);
});

// Equivalent to:
final cont2 = Cont.ask<DatabaseConfig>().thenDo((config) {
  return queryDatabase(config.connectionString);
});
```

---

### Cont.bracket

```dart
static Cont<E, A> bracket<E, R, A>({
  required Cont<E, R> acquire,
  required Cont<E, ()> Function(R resource) release,
  required Cont<E, A> Function(R resource) use,
})
```

Manages resource lifecycle with guaranteed cleanup.

The bracket pattern ensures that a resource is properly released after use, even if an error occurs during the `use` phase. Cancellation has limits, described below. This is the functional equivalent of try-with-resources or using statements.

**The execution order is:**
1. `acquire` - Obtain the resource
2. `use` - Use the resource to produce a value
3. `release` - Release the resource (runs when `use` finishes, whether it succeeds or fails)

**Cancellation behavior:**
- Cancellation is checked before the `use` phase; if cancelled, `use` is skipped but `release` still runs
- Release runs with a non-cancellable runtime, so cancellation does not stop it once it has started

**Limits under cancellation:**

Cancellation is cooperative and nothing is notified when it happens, so `bracket` only learns about it when `use` delivers a result.
- Cancelled while `use` runs: a cancelled computation stops without delivering anything, and a result that arrives after the cancellation is dropped. `use` therefore never reports back, `release` never runs, and the resource is not released.
- Cancelled while `acquire` runs: `acquire` can stop the same way after it has obtained the resource, which is then never released.

These limits are part of the 1.x cancellation design and are not fixed in 1.x.

**Error handling behavior:**
- If `acquire` fails: terminates immediately with `acquire` errors (neither `use` nor `release` execute)
- If `use` succeeds and `release` succeeds: returns the value from `use`
- If `use` succeeds and `release` fails: terminates with release errors
- If `use` fails and `release` succeeds: terminates with use errors
- If `use` fails and `release` fails: terminates with both error lists concatenated

- **Parameters:**
  - `acquire`: Continuation that acquires the resource
  - `release`: Function that takes the resource and returns a continuation that releases it
  - `use`: Function that takes the resource and returns a continuation that uses it

**Example:**
```dart
// With explicit type parameters: <Environment, Resource, Result>
final result = Cont.bracket<MyEnv, File, String>(
  acquire: openFile('data.txt'),           // Cont<MyEnv, File>
  release: (file) => closeFile(file),      // File => Cont<MyEnv, ()>
  use: (file) => readContents(file),       // File => Cont<MyEnv, String>
);

// Or using type inference (recommended):
final result = Cont.bracket(
  acquire: openFile('data.txt'),
  release: (file) => closeFile(file),
  use: (file) => readContents(file),
);
```

---

## Transformation

### decor

```dart
Cont<E, A> decor(void Function(void Function(ContRuntime<E>, ContObserver<A>) run, ContRuntime<E> runtime, ContObserver<A> observer) f)
```

Transforms the execution of the continuation using a natural transformation.

Applies a function that wraps or modifies the underlying run behavior. This is useful for intercepting execution to add middleware-like behavior such as logging, timing, or modifying how observers receive callbacks.

The transformation function receives both the original run function and the observer, allowing custom execution behavior to be injected.

- **Parameters:**
  - `f`: A transformation function that receives the run function and observer, and implements custom execution logic by calling the run function with the observer at the appropriate time

**Example:**
```dart
// Add logging around execution
final logged = cont.decor((run, runtime, observer) {
  print('Starting execution');
  run(runtime, observer);
  print('Execution initiated');
});

// Add timing
final timed = cont.decor((run, runtime, observer) {
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
