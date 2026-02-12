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

Constructs a continuation with guaranteed idempotence and exception catching. The run function receives an observer with `onThen` and `onElse` callbacks. The callbacks should be called as the last instruction in the run function or saved to be called later.

- **Parameters:**
  - `run`: Function that executes the continuation and calls observer callbacks

**Example:**
```dart
final cont = Cont.fromRun<MyEnv, int>((runtime, observer) {
  // Access environment
  final config = runtime.env();

  // Check cancellation
  if (runtime.isCancelled()) {
    observer.onElse([ContError.capture('Cancelled')]);
    return;
  }

  // Produce a value
  observer.onThen(42);
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

### Cont.bracket

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
3. `release` - Release the resource (always runs if `acquire` succeeded, even if `use` fails or is cancelled)

**Cancellation behavior:**
- The `release` function is called even when the runtime is cancelled
- Release runs with a non-cancellable runtime, ensuring complete cleanup
- Cancellation is checked before the `use` phase; if cancelled, `use` is skipped but `release` still runs

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
