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
- It is idempotent. Calling `onThen`, `onElse`, or `onCrash` more than once will do nothing.
- It is mandatory to call exactly one of `onThen`, `onElse`, or `onCrash` once the computation is over. Otherwise, errors will be lost, and behavior becomes undefined.
- The observer has an `isUsed` property that returns `true` once any callback has been invoked.
- Exceptions thrown inside `Cont.fromRun` are automatically caught and routed to the crash channel — you don't need to wrap your code in try-catch blocks.

### Deferred Construction

Sometimes you want to defer construction until the `Cont` is run:

```dart
Cont<E, String, User> getUserByIdThunk<E>(UserId Function() expensiveGetUserId) {
  return Cont.fromDeferred(() {
    final userId = expensiveGetUserId();
    final userCont = getUser(userId);
    return userCont;
  });
}
```

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
Cont.error<void, String, int>('User not found');
```

To represent a crash (unexpected exception):

```dart
Cont.crash<void, String, int>(someCrash);
```

### Resource Management

When working with resources that need cleanup (files, connections, locks), the `bracket` pattern guarantees the resource is released even if an error occurs.

```dart
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
      final contents = file.readStringSync();
      observer.onThen(contents);
    }),
  );
}
```

The execution order is always:
1. **Acquire** the resource
2. **Use** the resource
3. **Release** the resource (fire-and-forget)

Key details about `bracket`:
- `acquire` and `release` have error type `Never` — they can only succeed or crash, never produce a business-logic error.
- The `use` outcome (then, else, or crash) is propagated immediately; `release` runs independently afterward.
- Release outcomes are routed to the optional `onReleasePanic`, `onReleaseCrash`, and `onReleaseThen` callbacks.
- If the computation is cancelled before `use`, release fires and the observer receives nothing.

---

## 2. Run: Executing Computations

Constructing a computation is only the first step. To actually trigger its execution, call `run` on it. All callbacks (`onPanic`, `onCrash`, `onElse`, `onThen`) are optional named parameters with sensible defaults, so you only subscribe to the channels you care about.

The `run` method returns a **`ContCancelToken`** that you can use to cooperatively cancel the execution. Calling `token.cancel()` sets an internal flag that the runtime polls via `isCancelled()`, signalling that the computation should stop. You can also query the cancellation state at any time via `token.isCancelled()`.

```dart
// constructing the program
final Cont<void, String, int> program = getValueFromDatabase()
  .thenDo(incrementValue)
  .thenDo(isEven)
  .thenDo(toString);

// running the program with handlers
final token = program.run(
  null, // env
  onCrash: (crash) => print("crash=$crash"),
  onElse: (error) => print("error=$error"),
  onThen: (value) => print("value=$value"),
);

// or subscribe only to the value channel
final token = program.run(null, onThen: print);

// cancel the computation when needed
token.cancel();
```

### Key Properties of Cont

Any object of type `Cont` is:
- **Cold**: Doesn't run until you call `run`
- **Pure**: No side effects during construction
- **Lazy**: Evaluation is deferred
- **Reusable**: Can be safely executed multiple times

You can pass `Cont` objects around in functions and store them as values in constants.

### Run Parameters

The `run` method accepts the environment as a positional argument and four optional named parameters. It returns a `ContCancelToken`.

- **`onThen`** (default: no-op) — Receives the successful result of type `A`.
- **`onElse`** (default: no-op) — Receives the business-logic error of type `F`.
- **`onCrash`** (default: no-op) — Receives a `ContCrash` for unexpected exceptions.
- **`onPanic`** (default: re-throw) — Handles fatal errors that escape even the crash handlers.

Because every callback has a sensible default, you only need to subscribe to the channels you care about:

```dart
// Only handle values
final token = computation.run(env, onThen: print);

// Handle business errors and values
final token = computation.run(
  env,
  onElse: (error) => log(error),
  onThen: (value) => process(value),
);

// Handle all outcomes
final token = computation.run(
  env,
  onCrash: (crash) => reportCrash(crash),
  onElse: (error) => showError(error),
  onThen: (value) => display(value),
);

// Cancel when needed (e.g., on user action or timeout)
token.cancel();
```

**Panic handler:** The `onPanic` callback is invoked when a fatal error occurs that lies outside the normal crash channel — for example, when an observer callback itself throws an exception. It receives a `NormalCrash`. By default it re-throws the error, surfacing it as an unhandled exception. Override it to integrate with your logging or crash-reporting infrastructure.

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
  .run(null, onElse: onElse, onThen: onThen)  // Receives: value(2)
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
  .run(null, onCrash: onCrash, onThen: onThen)  // onCrash called
```

Similarly, `elseDo` only processes errors on the else channel, and `crashDo` only processes crashes:

```dart
Cont.error<void, String, int>('not found')  // Else channel
  .thenMap((x) => x + 1)    // Skipped (no value to process)
  .elseDo((error) => Cont.of(42))     // Recovers → switches to then channel
  .thenMap((x) => x * 2)    // Processes value(42) → value(84)
  .run(null, onThen: onThen)  // onThen(84) called
```

**Key Behaviors**

1. **Sequential by default**: Without racing/parallel operators, execution is strictly sequential
2. **Early termination**: An error or crash signal skips all value-processing operators downstream
3. **Recovery points**: `elseDo` catches errors and can resume normal flow; `crashDo` catches crashes
4. **Idempotent observers**: Each computation segment can only emit once—subsequent emissions are ignored
5. **Channel isolation**: Then, else, and crash channels are separate paths through the operator chain

### The Environment Parameter

You may have noticed the first parameter to `run` is an environment value (shown as `null` in examples above). This parameter serves a critical purpose in Jerelo's design.

**Why is environment needed?**

When you compose computations using operators like `thenDo`, `thenMap`, and `elseDo`, you create a chain of operations. However, these operations often need access to shared context like:
- Configuration values (API URLs, timeouts, feature flags)
- Dependencies (database connections, HTTP clients, loggers)
- Runtime context (user sessions, request IDs, auth tokens)

Without environment, you would need to manually pass these values through every single function in your chain, leading to verbose and brittle code.

**How environment works:**

Environment is automatically threaded through the entire computation chain. Any computation in the chain can access it using `Cont.askThen<E, F>()`, and you can create local scopes with different environment values using `.local()` or `.withEnv()`.

```dart
// Simple example: using void when you don't need environment
Cont.of(42).run(null, onThen: print);

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
- **Zero overhead when unused**: If you don't need environment, just use `void` as the type
- **Eliminates boilerplate**: No need to pass configuration through every function manually

For detailed environment operations including `local`, `withEnv`, and advanced patterns, see the [Environment Management](05-environment.md) guide.

---

## Next Steps

Now that you understand how to construct and run computations, continue to:
- **[Core Operations](03-core-operations.md)** - Learn to transform, chain, and branch computations
- **[Environment Management](05-environment.md)** - Deep dive into environment handling
