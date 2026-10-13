[Home](../../README.md) > User Guide

# Fundamentals: Construct & Run

This guide covers the basics of creating and executing computations with Jerelo.

## 1. Construct: Creating Computations

There are several ways to construct a `Cont` object.

### Basic Construction

Use `Cont.fromRun` for custom computations:

```dart
Cont<E, String, User> getUser<E>(String userId) {
  return Cont.fromRun((runtime, observer) {
    getUserById(userId, (user) {
      observer.onThen(user);
    });
  });
}
```

**Important notes about `observer`:**
- It is idempotent. Calling `onThen`, `onElse`, or `onCrash` more than once will do nothing. Only this observer is guarded: observers derived from it with `copyUpdate*` call their new callbacks every time.
- It is strongly advised to call exactly one of `onThen`, `onElse`, or `onCrash` once the computation is over.
- The observer has an `isUsed` property that returns `true` once any callback has been invoked.
- Exceptions thrown synchronously inside `Cont.fromRun` are automatically caught and routed to the crash channel — you don't need to wrap that code in try-catch blocks. An exception thrown later, inside a `Timer` or `Future` callback, is not caught: it escapes to the zone and the observer is never called. Wrap the body of such callbacks in `ContCrash.tryCatch` and pass the crash to `observer.onCrash`.

### Deferred Construction

Sometimes you want to defer construction until the `Cont` is run. Build the inner `Cont` inside `Cont.fromRun` and run it with `runWith`, passing the runtime and observer through:

```dart
Cont<E, String, User> getUserByIdThunk<E>(UserId Function() expensiveGetUserId) {
  return Cont.fromRun((runtime, observer) {
    final userId = expensiveGetUserId();
    final userCont = getUser<E>(userId);
    userCont.runWith(runtime, observer);
  });
}
```

`Cont.fromDeferred(() => ...)` wraps this pattern.

### Primitive Constructors

For a pure success value, use `Cont.of`:

```dart
Cont<E, F, User> getUser<E, F>(String userId) {
  final User user = getUserSync(userId); // evaluated eagerly
  return Cont.of(user);
}
```

To represent a business-logic error:

```dart
Cont.error<(), String, int>('User not found');
```

To represent a crash (unexpected exception):

```dart
Cont.crash<(), String, int>(someCrash);
```

This constructor is used to thread an existing `ContCrash`. A `NormalCrash` has no public
constructor: it is created when an exception is caught (for example by `ContCrash.tryCatch`).
`MergedCrash` and `CollectedCrash` have public constructors (also available as `ContCrash.merge`
and `ContCrash.collect`). (More in **[Composing Computations](03-composing-computations.md)**)

### Resource Management

When working with resources that need cleanup (files, connections, locks), the bracket pattern releases the resource whether `use` succeeds, fails, or crashes. Use `Cont.bracket`:

```dart
import 'package:jerelo/jerelo.dart';

Cont<E, F, String> readFileContents<E, F>(String path) {
  return Cont.bracket<RandomAccessFile, E, F, String>(
    acquire: Cont.fromRun((runtime, observer) {
      final file = File(path).openSync();
      observer.onThen(file);
    }),
    release: (file) => Cont.fromRun((runtime, observer) {
      file.closeSync();
      observer.onThen(());
    }),
    use: (file) => Cont.fromRun((runtime, observer) {
      final contents = String.fromCharCodes(file.readSync(file.lengthSync()));
      observer.onThen(contents);
    }),
  );
}
```

The execution order is always:
1. **Acquire** the resource
2. **Use** the resource
3. **Release** the resource (fire-and-forget)

Key details about `Cont.bracket`:
- `acquire` and `release` have error type `Never` — they can only succeed or crash, never produce a business-logic error.
- The `use` outcome (then, else, or crash) is propagated immediately; `release` runs independently afterward.
- Release outcomes are routed to the optional `onReleasePanic`, `onReleaseCrash`, and `onReleaseThen` callbacks. A throw from the `release` function itself (while building the release continuation) goes to `onReleasePanic`; a crash inside the returned continuation goes to `onReleaseCrash`.
- `release` runs once `use` reports an outcome. If `use` never reports, `release` never runs.

---

## 2. Run: Executing Computations

Constructing a computation is only the first step. To actually trigger its execution, call `run` on it. All callbacks (`onPanic`, `onCrash`, `onElse`, `onThen`) are optional named parameters with sensible defaults, so you only subscribe to the channels you care about.

`run` returns nothing: the outcome arrives only through the callbacks. Core has no cancellation; once started, a computation runs until it reports an outcome.

```dart
// constructing the program
final Cont<(), String, int> program = getValueFromDatabase()
  .thenDo(incrementValue)
  .thenDo(isEven)
  .thenDo(toString);

// running the program with handlers
program.run(
  (), // env
  onCrash: (crash) => print("crash=$crash"),
  onElse: (error) => print("error=$error"),
  onThen: (value) => print("value=$value"),
);

// or subscribe only to the value channel
program.run((), onThen: print);
```

### Key Properties of Cont

Any object of type `Cont` is:
- **Cold**: Doesn't run until you call `run`
- **Pure**: No side effects during construction
- **Lazy**: Evaluation is deferred
- **Reusable**: Can be safely executed multiple times

You can pass `Cont` objects around in functions and store them as values in constants.

### Run Parameters

The `run` method accepts the environment as a positional argument and four optional named parameters. It returns `void`.

- **`onThen`** (default: no-op) — Receives the successful result of type `A`.
- **`onElse`** (default: no-op) — Receives the business-logic error of type `F`.
- **`onCrash`** (default: no-op) — Receives a `ContCrash` for unexpected exceptions.
- **`onPanic`** (default: re-throw in a microtask) — Handles fatal errors that escape even the crash handlers.

Because every callback has a sensible default, you only need to subscribe to the channels you care about:

```dart
// Only handle values
computation.run(env, onThen: print);

// Handle business errors and values
computation.run(
  env,
  onElse: (error) => log(error),
  onThen: (value) => process(value),
);

// Handle all outcomes
computation.run(
  env,
  onCrash: (crash) => reportCrash(crash),
  onElse: (error) => showError(error),
  onThen: (value) => display(value),
);
```

**Panic handler:** The `onPanic` callback is invoked when a fatal error occurs that lies outside the normal crash channel — for example, when an observer callback itself throws an exception. It receives a `NormalCrash`. By default it re-throws the error in a microtask, surfacing it as an unhandled exception in the current zone; a `try`/`catch` around `run()` never sees it. Override it to integrate with your logging or crash-reporting infrastructure.

### Execution Flow

Understanding how `Cont` executes is crucial for building complex computation chains. The execution model follows a two-phase traversal pattern with channel-aware routing.

**Phase 1: Ascending the Chain**

When `run` is called, execution first traverses "up" the operator chain to find the source computation. This traversal passes through all intermediate operators (`thenMap`, `thenDo`, `elseDo`, etc.) without executing their logic yet—it's simply locating the origin of the computation chain.

```dart
// This chain: source → thenMap → thenDo → run
Cont.of(0)              // source (reached first)
  .thenMap((x) => x + 1)  // operator 2 (traversed)
  .thenDo((x) => ...)   // operator 3 (traversed)
  .run(...)             // starting point
```

**Phase 2: Descending Through Operators**

Once the source computation completes and emits a value, error, or crash, execution flows back "down" through each operator in reverse order:

1. **Source emits** → Value, error, or crash propagates down
2. **Each operator processes** → Transforms, chains, or routes the signal
3. **Final callback invoked** → `onThen`, `onElse`, or `onCrash` from `run`

```dart
Cont.of(0)                    // Emits: value(0)
  .thenMap((x) => x + 1)      // Processes: value(0) → value(1)
  .thenDo((x) => Cont.of(x * 2))  // Processes: value(1) → runs new Cont → value(2)
  .run((), onElse: onElse, onThen: onThen)  // Receives: value(2)
```

**Channel Routing and Switching**

Each operator in the chain routes signals through three channels:

- **Then channel**: Carries successful results (type `A`)
- **Else channel**: Carries typed business errors (type `F`)
- **Crash channel**: Carries unexpected exceptions (`ContCrash`)

Operators like `thenDo` and `thenMap` only process values from the then channel. If an error or crash signal arrives, they pass it through unchanged:

```dart
Cont.of(0)
  .thenMap((x) => x + 1)    // Only processes values
  .thenDo((x) => throw "Error!")  // Throws → switches to crash channel
  .thenMap((x) => x * 2)    // Skipped! (crash channel active)
  .run((), onCrash: onCrash, onThen: onThen)  // onCrash called
```

Similarly, `elseDo` only processes errors on the else channel, and `crashDo` only processes crashes:

```dart
Cont.error<(), String, int>('not found')  // Else channel
  .thenMap((x) => x + 1)    // Skipped (no value to process)
  .elseDo((error) => Cont.of(42))     // Recovers → switches to then channel
  .thenMap((x) => x * 2)    // Processes value(42) → value(84)
  .run((), onThen: onThen)  // onThen(84) called
```

**Key Behaviors**

1. **Sequential by default**: Without racing/parallel operators, execution is strictly sequential
2. **Early termination**: An error or crash signal skips all value-processing operators downstream
3. **Recovery points**: `elseDo` catches errors and can resume normal flow; `crashDo` catches crashes
4. **Idempotent observers**: Each computation segment can only emit once—subsequent emissions are ignored
5. **Channel isolation**: Then, else, and crash channels are separate paths through the operator chain

### The Environment Parameter

You may have noticed the first parameter to `run` is an environment value (shown as `()` in examples above). This parameter serves a critical purpose in Jerelo's design.

**Why is environment needed?**

When you compose computations using operators like `thenDo`, `thenMap`, and `elseDo`, you create a chain of operations. However, these operations often need access to shared context like:
- Configuration values (API URLs, timeouts, feature flags)
- Dependencies (database connections, HTTP clients, loggers)
- Runtime context (user sessions, request IDs, auth tokens)

Without environment, you would need to manually pass these values through every single function in your chain, leading to verbose and brittle code.

**How environment works:**

Environment is automatically threaded through the entire computation chain. Any computation in the chain can access it using `Cont.askThen<E, F>()`, and you can create local scopes with different environment values using `.local()`.

```dart
// Simple example: using () when you don't need environment
Cont.of(42).run((), onThen: print);

// Using environment to share configuration
class Config {
  final String apiUrl;
  Config(this.apiUrl);
}

final program = Cont.askThen<Config, String>().thenDo((config) {
  return fetchFromApi(config.apiUrl);
});

program.run(
  Config(apiUrl: "https://api.example.com"),
  onElse: (error) => print("Failed: $error"),
  onThen: (result) => print("Success: $result"),
);
```

**Key features:**

- **Type-safe**: The environment type `E` in `Cont<E, F, A>` ensures you can only run a computation with the correct environment type
- **Composable**: Different parts of your computation can use different environment types via `.local()`
- **Zero overhead when unused**: If you don't need environment, just use `()` as the type
- **Eliminates boilerplate**: No need to pass configuration through every function manually

For detailed environment operations including `local`, injection, and advanced patterns, see the [Environment Management](05-environment.md) guide.

---

## Next Steps

Now that you understand how to construct and run computations, continue to:
- **[Composing Computations](03-composing-computations.md)** - Master the operator toolkit
- **[Racing and Merging](04-racing-and-merging.md)** - Parallel composition and concurrency 
