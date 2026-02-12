[Home](../../README.md) > [Documentation](../README.md) > User Guide

# Fundamentals: Construct & Run

This guide covers the basics of creating and executing computations with Jerelo.

## 1. Construct: Creating Computations

There are several ways to construct a `Cont` object.

### Basic Construction

Use `Cont.fromRun` for custom computations:

```dart
Cont<E, User> getUser<E>(String userId) {
  return Cont.fromRun((runtime, observer) {
    try {
      final userFuture = getUserById(userId, (user) {
        observer.onThen(user);
      });
    } catch (error, st) {
      observer.onElse([ContError.withStackTrace(error, st)]);
    }
  });
}
```

**Important notes about `observer`:**
- It is idempotent. Calling `onThen` or `onElse` more than once will do nothing.
- It is mandatory to call `onThen` or `onElse` once the computation is over. Otherwise, errors will be lost, and behavior becomes undefined.

### Deferred Construction

Sometimes you want to defer construction until the `Cont` is run:

```dart
Cont<E, User> getUserByIdThunk<E>(UserId Function() expensiveGetUserId) {
  return Cont.fromDeferred(() {
    final userId = expensiveGetUserId();
    final userCont = getUser(userId);
    return userCont;
  });
}
```

### Primitive Constructors

For simple values, use `Cont.of`:

```dart
Cont<E, User> getUser<E>(String userId) {
  final User user = getUserSync(userId); // evaluated eagerly
  return Cont.of(user);
}
```

To represent terminated computation:

```dart
Cont.stop([
  ContError.capture("payload"),
]);
```

### Resource Management

When working with resources that need cleanup (files, connections, locks), the `bracket` pattern guarantees the resource is released even if an error occurs.

```dart
Cont<E, String> readFileContents<E>(String path) {
  return Cont.bracket<E, RandomAccessFile, String>(
    acquire: Cont.fromRun((runtime, observer) {
      try {
        final file = File(path).openSync();
        observer.onThen(file);
      } catch (error, st) {
        observer.onElse([ContError.withStackTrace(error, st)]);
      }
    }),
    release: (file) => Cont.fromRun((runtime, observer) {
      try {
        file.closeSync();
        observer.onThen(());
      } catch (error, st) {
        observer.onElse([ContError.withStackTrace(error, st)]);
      }
    }),
    use: (file) => Cont.fromRun((runtime, observer) {
      try {
        final contents = file.readStringSync();
        observer.onThen(contents);
      } catch (error, st) {
        observer.onElse([ContError.withStackTrace(error, st)]);
      }
    }),
  );
}
```

The execution order is always:
1. **Acquire** the resource
2. **Use** the resource
3. **Release** the resource

If the `use` phase fails, `release` still executes. Error handling follows these rules:
- Both succeed → returns the value from `use`
- `use` succeeds, `release` fails → terminates with release errors
- `use` fails, `release` succeeds → terminates with use errors
- Both fail → terminates with all errors combined

This pattern is essential for writing leak-free code when dealing with external resources like file handles, database connections, or network sockets.

---

## 2. Run: Executing Computations

Constructing a computation is only the first step. To actually trigger its execution, call `run` on it. All callbacks (`onElse`, `onThen`, `onPanic`) are optional named parameters with sensible defaults, so you only subscribe to the channels you care about.

The `run` method returns a **`ContCancelToken`** that you can use to cooperatively cancel the execution. Calling `token.cancel()` sets an internal flag that the runtime polls via `isCancelled()`, signalling that the computation should stop. You can also query the cancellation state at any time via `token.isCancelled()`.

```dart
// constructing the program
final Cont<(), String> program = getValueFromDatabase()
  .thenDo(incrementValue)
  .thenDo(isEven)
  .thenDo(toString);

// running the program with both handlers
final token = program.run(
  (), // env
  onElse: (errors) {
    // handle errors
    print("TERMINATED with errors=$errors");
  },
  onThen: (value) {
    // handle computed result
    print("SUCCEEDED with value=$value");
  },
);

// or subscribe only to the value channel
final token = program.run((), onThen: print);

// cancel the computation when needed
token.cancel();
```

### Fire-and-Forget Execution with ff

The `ff` method provides a simplified way to execute a continuation when you don't care about the result:

```dart
// Just run it and forget about it
logAnalytics(userId, action).ff(());

// vs. using run
logAnalytics(userId, action).run((), onThen: (_) {}, onElse: (_) {});
```

The `ff` method:
- Does not provide success or error callbacks
- Only accepts `onPanic` for fatal errors
- Useful for side-effect-only operations like logging, metrics, or fire-and-forget notifications
- More concise than `run` when you don't need to handle results

**Signature:**
```dart
void ff(E env, {void Function(ContError error) onPanic})
```

**Use cases:**
- Fire-and-forget logging
- Background analytics
- Non-critical notifications
- Metrics collection

### Key Properties of Cont

Any object of type `Cont` is:
- **Cold**: Doesn't run until you call `run`
- **Pure**: No side effects during construction
- **Lazy**: Evaluation is deferred
- **Reusable**: Can be safely executed multiple times

You can pass `Cont` objects around in functions and store them as values in constants.

### Run Parameters

The `run` method accepts the environment as a positional argument and three optional named parameters. It returns a `ContCancelToken`.

- **`onThen`** (default: no-op) — Receives the successful result.
- **`onElse`** (default: no-op) — Receives errors on termination.
- **`onPanic`** (default: re-throw in microtask) — Handles fatal, unrecoverable errors.

The method returns a **`ContCancelToken`** that cooperatively cancels the execution via `cancel()` and exposes cancellation state via `isCancelled()`.

Because every callback has a sensible default, you only need to subscribe to the channels you care about:

```dart
// Only handle values
final token = computation.run(env, onThen: print);

// Handle both outcomes
final token = computation.run(
  env,
  onElse: (errors) => log(errors),
  onThen: (value) => process(value),
);

// Cancel when needed (e.g., on user action or timeout)
token.cancel();
```

**Panic handler:** The `onPanic` callback is invoked when a fatal error occurs that lies outside the normal termination channel — for example, when an observer callback itself throws an exception. By default it re-throws the error inside a `scheduleMicrotask`, surfacing it as an unhandled exception. Override it to integrate with your logging or crash-reporting infrastructure.

### Execution Flow

Understanding how `Cont` executes is crucial for building complex computation chains. The execution model follows a two-phase traversal pattern with channel-aware routing.

**Phase 1: Ascending the Chain**

When `run` is called, execution first traverses "up" the operator chain to find the source computation. This traversal passes through all intermediate operators (`map`, `thenDo`, `elseDo`, etc.) without executing their logic yet—it's simply locating the origin of the computation chain.

```dart
// This chain: source → thenMap → thenDo → run
Cont.of(0)              // source (reached first)
  .thenMap((x) => x + 1)  // operator 2 (traversed)
  .thenDo((x) => ...)   // operator 3 (traversed)
  .run(...)             // starting point
```

**Phase 2: Descending Through Operators**

Once the source computation completes and emits a value or termination, execution flows back "down" through each operator in reverse order:

1. **Source emits** → Value or termination propagates down
2. **Each operator processes** → Transforms, chains, or routes the signal
3. **Final callback invoked** → Either `onThen` or `onElse` from `run`

```dart
Cont.of(0)                    // Emits: value(0)
  .thenMap((x) => x + 1)      // Processes: value(0) → value(1)
  .thenDo((x) => Cont.of(x * 2))  // Processes: value(1) → runs new Cont → value(2)
  .run((), onElse: onElse, onThen: onThen)  // Receives: value(2)
```

**Channel Routing and Switching**

Each operator in the chain routes signals through two channels:

- **Value channel**: Carries successful results (type `T`)
- **Termination channel**: Carries errors (`List<ContError>`)

Operators like `thenDo` and `map` only process values from the value channel. If a termination signal arrives, they pass it through unchanged to the next operator:

```dart
Cont.of(0)
  .thenMap((x) => x + 1)    // Only processes values
  .thenDo((x) => throw "Error!")  // Throws → switches to termination channel
  .thenMap((x) => x * 2)    // Skipped! (termination channel active)
  .run((), onElse: onElse, onThen: onThen)  // onElse called
```

Conversely, `elseDo` and `elseTap` only process termination signals and can switch back to the value channel:

```dart
Cont.stop<(), int>([ContError.withStackTrace("fail", st)])  // Termination channel
  .thenMap((x) => x + 1)    // Skipped (no value to process)
  .elseDo((errors) {
    return Cont.of(42);     // Recovers → switches back to value channel
  })
  .thenMap((x) => x * 2)    // Processes value(42) → value(84)
  .run((), onElse: onElse, onThen: onThen)  // onThen(84) called
```

**Pausing for Racing Continuations**

When using racing operators (`either`, `any`) or parallel execution policies (e.g., `ContBothPolicy.quitFast()` or `ContEitherPolicy.quitFast()`), multiple continuations execute simultaneously. The execution flow pauses at the racing operator until a decisive result is reached:

```dart
final slow = delay(Duration(seconds: 2), 42);
final fast = delay(Duration(milliseconds: 100), 10);

Cont.either(slow, fast, ...)  // Both start executing in parallel
  .thenMap((x) => x * 2)      // Waits for first completion → then processes winner
  .run(...)                   // Receives result from fast: 10 * 2 = 20
```

During this pause:
- Multiple computation chains run concurrently
- The racing operator monitors all channels (both value and termination)
- As soon as one chain produces a decisive result (first success for `either`, first failure for `all`), others may be cancelled
- The winning result continues down the remaining operator chain

**Key Behaviors**

1. **Sequential by default**: Without racing/parallel operators, execution is strictly sequential
2. **Early termination**: A termination signal skips all value-processing operators downstream
3. **Recovery points**: `elseDo` can catch terminations and resume normal (value) flow
4. **Idempotent observers**: Each computation segment can only emit once—subsequent emissions are ignored
5. **Channel isolation**: Value and termination channels are separate paths through the operator chain

### The Environment Parameter

You may have noticed the first parameter to `run` is an environment value (shown as `()` in examples above). This parameter serves a critical purpose in Jerelo's design.

**Why is environment needed?**

When you compose computations using operators like `thenDo`, `map`, and `elseDo`, you create a chain of operations. However, these operations often need access to shared context like:
- Configuration values (API URLs, timeouts, feature flags)
- Dependencies (database connections, HTTP clients, loggers)
- Runtime context (user sessions, request IDs, auth tokens)

Without environment, you would need to manually pass these values through every single function in your chain, leading to verbose and brittle code.

**How environment works:**

Environment is automatically threaded through the entire computation chain. Any computation in the chain can access it using `Cont.ask<YourEnvType>()`, and you can create local scopes with different environment values using `.scope()`.

```dart
// Simple example: using () when you don't need environment
Cont.of(42).run((), onThen: print);

// Using environment to share configuration
class Config {
  final String apiUrl;
  Config(this.apiUrl);
}

final program = Cont.ask<Config>().thenDo((config) {
  return fetchFromApi(config.apiUrl);
});

program.run(
  Config(apiUrl: "https://api.example.com"), // provide environment
  onElse: (errors) => print("Failed: $errors"),
  onThen: (result) => print("Success: $result"),
);
```

**Key features:**

- **Type-safe**: The environment type `E` in `Cont<E, T>` ensures you can only run a computation with the correct environment type
- **Composable**: Different parts of your computation can use different environment types via `.scope()`
- **Zero overhead when unused**: If you don't need environment, just use `()` as the unit type
- **Eliminates boilerplate**: No need to pass configuration through every function manually

For detailed environment operations including `scope`, `WithEnv` variants, and advanced patterns, see the [Environment Management](05-environment.md) guide.

---

## Next Steps

Now that you understand how to construct and run computations, continue to:
- **[Core Operations](03-core-operations.md)** - Learn to transform, chain, and branch computations
- **[Environment Management](05-environment.md)** - Deep dive into environment handling
- **[API Reference](../api.md)** - Quick reference lookup
