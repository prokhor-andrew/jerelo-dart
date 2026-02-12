# Jerelo User Guide

## Table of Contents

- [What is Jerelo?](#what-is-jerelo)
  - [Understanding Computation](#understanding-computation)
  - [Why Composition Matters](#why-composition-matters)
  - [What is Continuation?](#what-is-continuation)
  - [What Problem Does CPS Solve?](#what-problem-does-cps-solve)
  - [Why Not Future?](#why-not-future)
  - [The Problem of CPS](#the-problem-of-cps)
  - [The Solution: Jerelo's Cont](#the-solution-jerelos-cont)
  - [What "Jerelo" Means](#what-jerelo-means)
- [Getting Started with Cont](#getting-started-with-cont)
  - [Result Channels](#result-channels)
  - [ContError Type](#conterror-type)
- [1. Construct: Creating Computations](#1-construct-creating-computations)
  - [Basic Construction](#basic-construction)
  - [Deferred Construction](#deferred-construction)
  - [Primitive Constructors](#primitive-constructors)
  - [Resource Management](#resource-management)
- [2. Run: Executing Computations](#2-run-executing-computations)
  - [Key Properties of Cont](#key-properties-of-cont)
  - [Execution Flow](#execution-flow)
  - [The Environment Parameter](#the-environment-parameter)
- [3. Transform: Modifying Values](#3-transform-modifying-values)
  - [Mapping](#mapping)
  - [Hoisting](#hoisting)
- [4. Chain: Sequencing Computations](#4-chain-sequencing-computations)
  - [Success Chaining](#success-chaining)
  - [Error Chaining](#error-chaining)
  - [Environment Variants](#environment-variants)
- [5. Branch: Conditional Logic](#5-branch-conditional-logic)
  - [Conditional Execution](#conditional-execution)
  - [Looping with asLongAs](#looping-with-aslongas)
  - [Looping with until](#looping-with-until)
- [Execution Policies](#execution-policies)
  - [Policy Types](#policy-types)
- [6. Merge: Combining Computations](#6-merge-combining-computations)
  - [Running Two Computations](#running-two-computations)
  - [Running Many Computations](#running-many-computations)
  - [Racing Computations](#racing-computations)
- [Environment Management](#environment-management)
  - [Accessing Environment](#accessing-environment)
  - [Scoping Environment](#scoping-environment)
  - [WithEnv Variants](#withenv-variants)
  - [Dependency Injection Patterns](#dependency-injection-patterns)
- [Creating Custom Extensions](#creating-custom-extensions)
  - [Custom Computations](#custom-computations)
  - [Custom Operators](#custom-operators)
  - [Cancellation with Runtime](#cancellation-with-runtime)
- [Complete Example](#complete-example)
- [API Reference](#api-reference)

---

## What is Jerelo?

**Jerelo** is a Dart library for building cold, lazy, reusable computations. It provides operations for chaining, transforming, branching, merging, and error handling.

### Understanding Computation

A **computation** is a constructible description of how a value can be produced. Its key feature is the separation of construction from execution.

```dart
// construction of the computation
Future<int> getValue() {
  return Future.delayed(Duration(seconds: 1), () {
    return 42;
  });
}

// execution of the computation
getValue();
```

It's worth noting that `Future<int>` is **not** a computation. `getValue` is.

Whenever we construct a future object, its execution starts immediately. We cannot run it later.

### Why Composition Matters

The reason we care about computations is their ability to compose.

**Composition** is a technique of combining two or more computations together to get a new one.

Composability guarantees many important features such as:
- Reusability
- Testability
- Substitution
- Observability
- Refactorability (if that's a word)

and many more.

### What is Continuation?

Usually when you need to encode a computation, you use functions that return a value.

```dart
int increment(int value) {
  return value + 1;
}

final result = increment(5); // 6
```

Another way to achieve the same result is to use **Continuation-Passing Style** (CPS).

```dart
// `callback` is a continuation
void increment(int value, void Function(int result) callback) {
  callback(value + 1);
}

increment(5, (result) {
  // result == 6
});
```

Instead of returning a result, a callback is passed to the function. When the result is computed, the callback is invoked with a value.

### What Problem Does CPS Solve?

The classic pure function can only be executed synchronously. By its encoding, it is forced to return a value immediately on the same call stack. In CPS, the continuation is passed, which can be saved and executed at any time later. This enables asynchronous programming.

### Why Not Future?

Dart's `Future` is, in fact, CPS with syntactic sugar on top of it. But as it was mentioned above, `Future` starts running as soon as it is created, thus it is not composable.

```dart
final getUserComputation = Future(() {
  // getting user here
});

// getUserComputation is already running.
```

### The Problem of CPS

While normal functions and `Future`s compose nicely, CPS doesn't.

```dart
// normal composition
final result1 = function1(value);
final result2 = function2(result1);
final result3 = function3(result2);

// async composition
// in async function

final result1 = await function1(value);
final result2 = await function2(result1);
final result3 = await function3(result2);

// CPS composition
function1(value, (result1) {
  function2(result1, (result2) {
    function3(result2, (result3) {
      // the rest of the program
    });
  });
});
```

As you can see, the more functions we want to compose, the uglier it becomes.

### The Solution: Jerelo's Cont

**Cont** is a type that represents an arbitrary computation. It has two result channels, and comes with a basic interface that allows you to do every fundamental operation:
- Construct
- Run
- Transform
- Chain
- Branch
- Merge

Example of `Cont`'s composition:

```dart
// Cont composition

final program = function1(value)
  .thenDo(function2)
  .thenDo((result2) {
    // the rest of the program
  });
```

### What "Jerelo" Means

**Jerelo** is a Ukrainian word meaning "source" or "spring".

Each `Cont` is a source of results. Like a spring that feeds a stream, a `Cont` produces a flow of data. Streams can branch, merge, filter, and transform what they carry, and Jerelo's API lets you model the same kinds of operations in your workflows.

---

## Getting Started with Cont

`Cont` has two result channels:
- **Success channel**: Represented by the type parameter `T` in `Cont<E, T>`
- **Termination channel**: Represented by `List<ContError>` for errors that caused termination

### Result Channels

The termination channel is used when a computation crashes or when you manually terminate it.

```dart
final program = getUserAge(userId).thenMap((age) {
  throw "Armageddon!"; // <- throws here
});

// or

final program = getUserAge(userId).thenDo((age) {
  return Cont.stop([ContError.capture("Armageddon!")]);
});

// ignore `()` for now
final token = program.run(
  (),
  onElse: (errors) {
    // will automatically catch thrown error here
  },
  onThen: (value) {
    // success channel. not called in this case
    print("value=$value");
  },
);
```

### ContError Type

The type of a thrown error is `ContError`. It is a holder for the original error and stack trace. Instances are created via static factory methods:

```dart
final class ContError {
  final Object error;
  final StackTrace stackTrace;

  // From a catch block — preserves the caught stack trace
  ContError.withStackTrace(error, stackTrace);

  // When no stack trace is needed
  ContError.withNoStackTrace(error);

  // Captures the stack trace at the call site automatically
  ContError.capture(error);
}
```

---

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
Cont.stop<int>([ContError.withStackTrace("fail", st)])  // Termination channel
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

For detailed environment operations including `scope`, `WithEnv` variants, and advanced patterns, see the [Environment Management](#environment-management) section.

---

## 3. Transform: Modifying Values

### Mapping

To transform a value inside `Cont`, use `thenMap`:

```dart
Cont.of(0).thenMap((zero) {
  return zero + 1;
}).run((), onThen: print); // prints 1
```

**Variants:**
- `thenMap(f)` - Transform value with function
- `thenMap0(f)` - Transform with zero-argument function (ignores current value)
- `thenMapWithEnv(f)` - Transform with access to environment and value
- `thenMapWithEnv0(f)` - Transform with access to environment only
- `thenMapTo(value)` - Replace value with a constant

### Hoisting

Sometimes you need to intercept or modify how a continuation executes, without changing the value it produces. The `decor` operator lets you wrap the underlying run function with custom behavior.

Sometimes you need to intercept or modify how a continuation executes, without changing the value it produces. The `decor` operator lets you wrap the underlying run function with custom behavior.

This is useful for:
- Logging when execution starts
- Adding timing/profiling
- Wrapping with try-catch for additional error handling
- Scheduling
- Modifying observer behavior

```dart
// `delay` is not a real operator. It is a contrived example.
final cont = Cont.of(42).delay(Duration(milliseconds: 2));

// Add logging around execution
final logged = cont.decor((run, runtime, observer) {
  print('Execution starting...');
  run(runtime, observer);
  print('Execution initiated');
});

logged.run((), onThen: print);
// Prints:
// Execution starting...
// Execution initiated
// 42
```

**Note:** `decor` is a natural transformation that gives you full control over the execution mechanics, making it the most powerful operator for creating custom behaviors.

---

## 4. Chain: Sequencing Computations

Chaining is constructing a computation from the result of the previous one. This is the heart of composing computations.

Jerelo provides two families of chaining operators:
- **Success operators** (`then*`): Continue the chain when computation succeeds
- **Error operators** (`else*`): Handle termination and provide fallbacks

### Success Chaining

Use `thenDo` to chain computations based on success values:

```dart
Cont.of(0).thenDo((zero) {
  return Cont.of(zero + 1);
}).run((), onThen: print); // prints 1
```

Other success operators include:
- `thenTap`: Execute side effects while passing the original value through
- `thenZip`: Combine the original value with a new computation's result
- `thenFork`: Run a computation in the background without blocking the chain (fire-and-forget)

**Variants:** All success operators have `0`, `WithEnv`, and `WithEnv0` variants (e.g., `thenDo0`, `thenDoWithEnv`, `thenDoWithEnv0`)

Here's how chaining makes composition clean:

```dart
final program = function1(value)
  .thenDo(function2)
  .thenDo((result2) {
    // the rest of the program
  });
```

This is a dramatic improvement over the nested callback style!

### Error Chaining

Use `elseDo` to recover from termination by providing a fallback:

```dart
Cont.stop<int>([ContError.capture("fail")])
  .elseDo((errors) {
    print("Caught: ${errors[0].error}");
    return Cont.of(42); // recover with default value
  })
  .run((), onThen: print); // prints: Caught: fail, then: 42
```

**Variants:** `elseDo0`, `elseDoWithEnv`, `elseDoWithEnv0`

### Error Transformation with elseMap

The `elseMap` operator transforms the error list on the termination channel without changing the channel (stays on termination). This is useful for adding context, filtering errors, or wrapping errors in a different format.

```dart
Cont.stop<int>([ContError.capture("connection timeout")])
  .elseMap((errors) {
    return errors.map((e) =>
      ContError.capture("Network error: ${e.error}")
    ).toList();
  })
  .run(
    (),
    onElse: (errors) => print(errors.first.error),
  ); // prints "Network error: connection timeout"
```

**Difference from `elseDo`:**
- `elseMap`: Transforms errors and stays on termination channel (returns `List<ContError>`)
- `elseDo`: Can recover to success channel (returns `Cont<E, A>`)

**Variants:** `elseMap0`, `elseMapWithEnv`, `elseMapWithEnv0`, `elseMapTo`

### Other Error Operators

- `elseTap`: Execute side effects on termination (e.g., logging) while preserving the original errors
- `elseZip`: Runs fallback and combines errors from both attempts
- `elseFork`: Handle errors in the background without blocking (fire-and-forget)
- `recover`: Compute a replacement value from the errors (convenience shorthand for `elseDo`)
- `recover0`: Compute a replacement value ignoring the errors
- `recoverWith`: Provide a constant fallback value on termination

**Variants:** All error operators have `0`, `WithEnv`, and `WithEnv0` variants

### Environment Variants

All chaining operators have `WithEnv` variants that provide access to the environment parameter. These are explained in detail in the [WithEnv Variants](#withenv-variants) section.

```dart
Cont.of(42).thenDoWithEnv((env, value) {
  return fetchWithConfig(env.apiUrl, value);
});

computation.elseDoWithEnv((env, errors) {
  return loadFromCache(env.cacheDir);
});
```

---

## 5. Branch: Conditional Logic

Branching operators allow you to conditionally execute or repeat computations based on predicates.

### Conditional Execution

The `thenIf` operator filters a computation based on a predicate. If the predicate returns `true`, the computation succeeds with the value. If it returns `false`, the computation terminates without errors.

```dart
Cont.of(5)
  .thenIf((value) => value > 3)
  .run(
    (),
    onElse: (_) => print("terminated"),
    onThen: (value) => print("success: $value"),
  ); // prints "success: 5"

Cont.of(2)
  .thenIf((value) => value > 3)
  .run(
    (),
    onElse: (_) => print("terminated"),
    onThen: (value) => print("success: $value"),
  ); // prints "terminated"
```

This is useful for early termination of computation chains when certain conditions are not met.

**Variants:** `thenIf0`, `thenIfWithEnv`, `thenIfWithEnv0`

#### Conditional Recovery with elseIf

The `elseIf` operator is the error-channel counterpart to `thenIf`. While `thenIf` filters values on the success channel, `elseIf` filters errors on the termination channel and provides conditional recovery.

If the predicate returns `true`, the computation recovers with the provided value. If the predicate returns `false`, the computation continues terminating with the original errors.

```dart
Cont.stop<(), int>([ContError.capture('not found')])
  .elseIf((errors) => errors.first.error == 'not found', 42)
  .run(
    (),
    onElse: (_) => print("terminated"),
    onThen: (value) => print("success: $value"),
  ); // prints "success: 42"

Cont.stop<(), int>([ContError.capture('fatal error')])
  .elseIf((errors) => errors.first.error == 'not found', 42)
  .run(
    (),
    onElse: (errors) => print("terminated: ${errors.first.error}"),
    onThen: (value) => print("success: $value"),
  ); // prints "terminated: fatal error"
```

**Variants:** `elseIf0`, `elseIfWithEnv`, `elseIfWithEnv0`

This is particularly useful for:
- Recovering from specific error types while propagating others
- Implementing fallback values based on error conditions
- Creating error-handling strategies that depend on the error context

**Real-world example: Handling network errors with fallbacks**

```dart
fetchUserFromNetwork(userId)
  .elseIf(
    (errors) => errors.any((e) => e.error.toString().contains('404')),
    User.guest(), // Use guest user if not found
  )
  .elseIf(
    (errors) => errors.any((e) => e.error.toString().contains('timeout')),
    User.cached(userId), // Use cached user on timeout
  )
  .elseDo((errors) {
    // All other errors propagate
    return Cont.stop(errors);
  })
  .run(
    (),
    onElse: (errors) => print("Failed to get user: $errors"),
    onThen: (user) => print("Got user: ${user.name}"),
  );
```

#### Branching with thenIf-thenDo-elseDo

While `thenIf` is powerful on its own, combining it with `thenDo` and `elseDo` creates an elegant if-then-else pattern that's fully composable. Since `thenIf` terminates when the predicate is false, you can use `elseDo` to recover from that termination and provide an alternative path:

```dart
Cont.of(5)
  .thenIf((value) => value > 3)
  .thenDo((value) {
    // Handle the "if true" branch
    return Cont.of("Value $value is greater than 3");
  })
  .elseDo((errors) {
    // Handle the "if false" branch
    return Cont.of("Value was not greater than 3");
  })
  .run((), onThen: print); // prints "Value 5 is greater than 3"

Cont.of(2)
  .thenIf((value) => value > 3)
  .thenDo((value) {
    // This won't execute because predicate is false
    return Cont.of("Value $value is greater than 3");
  })
  .elseDo((errors) {
    // This executes as a fallback
    return Cont.of("Value was not greater than 3");
  })
  .run((), onThen: print); // prints "Value was not greater than 3"
```

This pattern is particularly handy because:
- **Composable**: Both branches return `Cont`, so they can be further chained
- **Type-safe**: The result type is consistent across both branches
- **Readable**: Clearly expresses conditional logic without nesting
- **Integrated**: Fits naturally into longer computation chains

```dart
// Real-world example: validate user age and take different actions
getUserAge(userId)
  .thenIf((age) => age >= 18)
  .thenDo((age) => grantFullAccess(userId))
  .elseDo((_) => grantRestrictedAccess(userId))
  .thenDo((accessLevel) => logAccessGrant(userId, accessLevel))
  .run(
    (),
    onElse: (errors) => print("Failed to process user: $errors"),
    onThen: (result) => print("Access granted: $result"),
  );
```

### Forced Termination with abort

The `abort` operator unconditionally switches to the termination channel with computed errors, regardless of whether the computation succeeded or failed. This is useful when you need to forcefully terminate based on the result value.

```dart
Cont.of(42)
  .abort((value) => [ContError.capture("Value $value is not allowed")])
  .run(
    (),
    onElse: (errors) => print("Terminated: ${errors.first.error}"),
    onThen: (value) => print("Success: $value"),
  ); // prints "Terminated: Value 42 is not allowed"
```

The key difference from `thenIf` is that `abort` computes the error list dynamically from the value, while `thenIf` simply filters without producing custom errors.

**Variants:**
- `abort(f)` - Compute errors from value
- `abort0(f)` - Compute errors without examining value
- `abortWithEnv(f)` - Compute errors with environment access
- `abortWithEnv0(f)` - Compute errors from environment only
- `abortWith(errors)` - Unconditionally terminate with fixed error list

**Example: Validation with custom error messages**

```dart
getUserInput()
  .abortWith([ContError.capture("Input required")])
    .thenIf((input) => input.isNotEmpty)
  .abort((input) {
    if (input.length < 3) {
      return [ContError.capture("Input too short: minimum 3 characters")];
    }
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(input)) {
      return [ContError.capture("Input must contain only letters")];
    }
    return []; // Won't actually abort if empty list
  })
  .thenDo((validInput) => processInput(validInput))
  .run(
    (),
    onElse: (errors) => print("Validation failed: ${errors.first.error}"),
    onThen: (result) => print("Processed: $result"),
  );
```

### Looping with thenWhile

The `thenWhile` operator repeatedly executes a computation as long as the predicate returns `true`. The loop stops when the predicate returns `false`, and the computation succeeds with that final value.

```dart
// Retry getting a value until it's greater than 5
Cont.of(0)
  .thenMap((n) => Random().nextInt(10)) // generate random 0..9
  .thenWhile((value) => value <= 5)
  .run((), onThen: (value) {
    print("Got value > 5: $value");
  });
```

The loop is stack-safe and handles asynchronous continuations correctly. If the continuation terminates or the predicate throws, the loop stops and propagates the errors.

Ideal for:
- Retry logic with conditions
- Polling until a state changes
- Repeating operations while a condition holds

**Variants:** `thenWhile0`, `thenWhileWithEnv`, `thenWhileWithEnv0`

### Looping with thenUntil

If you want to loop until a condition is met (inverted logic), use `thenUntil`:

```dart
// Retry getting a value until it's greater than 5
Cont.of(0)
  .thenMap((n) => Random().nextInt(10)) // generate random 0..9
  .thenUntil((value) => value > 5) // inverted condition
  .run((), onThen: (value) {
    print("Got value > 5: $value");
  });
```

**Variants:** `thenUntil0`, `thenUntilWithEnv`, `thenUntilWithEnv0`

### Looping forever

Use `forever` to create an infinite loop that never terminates normally:

```dart
Cont.of(())
  .thenTap((_) => checkForMessages())
  .thenTap((_) => delay(Duration(seconds: 1)))
  .forever()
  .run((), onElse: (errors) {
    print("Loop terminated: $errors");
  });
```

The `forever` operator returns `Cont<E, Never>`, indicating it never produces a value on the success channel. It can only terminate through errors or cancellation.

### Working with Never-Producing Continuations

Some operations produce `Cont<E, Never>`, meaning they can only terminate through errors, never through success. Jerelo provides special extensions for working with these:

#### trap: Execute Termination-Only Continuation

The `trap` method executes a `Cont<E, Never>` when you only care about errors:

```dart
final neverSucceeds = Cont.of(())
  .thenDo((_) => Cont.stop([ContError.capture("always fails")]))
  .forever();

// Only provide error handler - no onThen needed
final token = neverSucceeds.trap(
  (),
  onElse: (errors) => print("Terminated: ${errors.first.error}"),
);
```

Since `Cont<E, Never>` can never succeed, `trap` doesn't require an `onThen` callback, making your intent clearer.

#### absurd: Convert Never to Any Type

The `absurd` method converts a `Cont<E, Never>` to any result type. This is safe because the continuation can never actually produce a value:

```dart
final Cont<(), Never> neverProduces = loopForever();

// Convert to any type you need
final Cont<(), String> asString = neverProduces.absurd<String>();
final Cont<(), int> asInt = neverProduces.absurd<int>();

// This is safe because if neverProduces actually terminates,
// it will be through the error channel, not by producing a value
```

**Use cases for Never-producing continuations:**
- Long-running services that should never exit normally
- Event loops that only terminate on errors
- Infinite retry mechanisms
- Daemon processes
- WebSocket listeners

### Error Retry Loops with elseWhile and elseUntil

Just as `thenWhile` and `thenUntil` loop on the success channel, `elseWhile` and `elseUntil` provide retry logic on the error channel.

#### elseWhile: Retry while predicate is true

The `elseWhile` operator retries a computation as long as the error predicate returns `true`:

```dart
// Retry while getting network timeouts, up to 3 times
int attempts = 0;
fetchFromApi()
  .elseWhile((errors) {
    attempts++;
    final isTimeout = errors.any((e) => e.error.toString().contains('timeout'));
    return isTimeout && attempts < 3;
  })
  .run(
    (),
    onElse: (errors) => print("Failed after retries: ${errors.first.error}"),
    onThen: (data) => print("Success: $data"),
  );
```

**Variants:** `elseWhile0`, `elseWhileWithEnv`, `elseWhileWithEnv0`

#### elseUntil: Retry until predicate is true

The `elseUntil` operator retries until the error predicate returns `true` (inverted logic):

```dart
// Retry until we get a non-retryable error or succeed
fetchFromApi()
  .elseUntil((errors) {
    // Stop retrying if error is not retryable
    return errors.any((e) => e.error.toString().contains('unauthorized'));
  })
  .run(
    (),
    onElse: (errors) => print("Stopped retrying: ${errors.first.error}"),
    onThen: (data) => print("Success: $data"),
  );
```

**Variants:** `elseUntil0`, `elseUntilWithEnv`, `elseUntilWithEnv0`

**Common use cases:**
- Retry with exponential backoff (combine with `delay`)
- Retry on transient errors (network timeouts, rate limits)
- Circuit breaker patterns
- Polling until success or non-retryable error

---

## Execution Policies

When running multiple computations in parallel (using `both`, `all`, `either`, or `any`), you need to specify an **execution policy** that determines how the computations are run and how their results or errors are combined.

Jerelo provides two distinct policy types to match the different semantics of these operations:
- **`ContBothPolicy`** - for `both` and `all` operations (where all must succeed)
- **`ContEitherPolicy<A>`** - for `either` and `any` operations (racing for first success)

The split ensures type safety: `both`/`all` policies handle error combining, while `either`/`any` policies handle result combining for multiple successes.

### Policy Types

#### For `both` and `all` operations: ContBothPolicy

##### 1. Sequential Policy (`ContBothPolicy.sequence()`)

Executes computations one after another in order. Stops at the first failure.

```dart
final result = Cont.all(
  [computation1, computation2, computation3],
  policy: ContBothPolicy.sequence(),
);
```

**Use when:** You need predictable ordering or when computations depend on resources that shouldn't be accessed simultaneously.

##### 2. Merge When All Policy (`ContBothPolicy.mergeWhenAll()`)

Runs all computations in parallel and waits for all to complete. Concatenates errors if any fail.

```dart
final result = Cont.all(
  computations,
  policy: ContBothPolicy.mergeWhenAll(),
);
```

**Use when:** You want to collect all errors and make decisions based on the complete picture.

##### 3. Quit Fast Policy (`ContBothPolicy.quitFast()`)

Terminates as soon as the first failure occurs.

```dart
final result = Cont.both(
  computation1,
  computation2,
  (a, b) => (a, b),
  policy: ContBothPolicy.quitFast(),
);
```

**Use when:** You want the fastest possible feedback and don't need to wait for all operations to complete.

#### For `either` and `any` operations: ContEitherPolicy

##### 1. Sequential Policy (`ContEitherPolicy.sequence()`)

Executes computations one after another in order. Continues until one succeeds or all fail.

```dart
final result = Cont.either(
  primarySource,
  fallbackSource,
  policy: ContEitherPolicy.sequence(),
);
```

**Use when:** You have a preferred order and want to try alternatives sequentially.

##### 2. Merge When All Policy (`ContEitherPolicy.mergeWhenAll(combine)`)

Runs all computations in parallel and waits for all to complete. If multiple succeed, combines their results using the provided `combine` function.

```dart
final result = Cont.any(
  computations,
  policy: ContEitherPolicy.mergeWhenAll((first, second) => first), // Take the first result
);
```

**Use when:** You want to wait for all operations and potentially combine multiple successful results.

##### 3. Quit Fast Policy (`ContEitherPolicy.quitFast()`)

Terminates as soon as the first success occurs.

```dart
final result = Cont.either(
  primarySource,
  fallbackSource,
  policy: ContEitherPolicy.quitFast(),
);
```

**Use when:** You want the fastest possible feedback and don't need to wait for other operations to complete.

---

## 6. Merge: Combining Computations

Jerelo provides powerful operators for running multiple computations and combining their results. All merge operations require an execution policy (see above) to determine how computations are run and how results are combined.

### Running Two Computations

Use `both` to run two computations and combine their results:

```dart
final left = Cont.of(10);
final right = Cont.of(20);

Cont.both(
  left,
  right,
  (a, b) => a + b,
  policy: ContBothPolicy.quitFast(), // Runs in parallel, quits on first failure
).run((), onThen: print); // prints: 30
```

You can also use the instance method `and` as a more fluent alternative:

```dart
final left = Cont.of(10);
final right = Cont.of(20);

left.and(
  right,
  (a, b) => a + b,
  policy: ContBothPolicy.quitFast(),
).run((), onThen: print); // prints: 30
```

### Running Many Computations

Use `all` to run multiple computations and collect all results:

```dart
final computations = [
  Cont.of(1),
  Cont.of(2),
  Cont.of(3),
];

Cont.all(
  computations,
  policy: ContBothPolicy.quitFast(), // Runs in parallel, quits on first failure
).run((), onThen: print); // prints: [1, 2, 3]
```

### Racing Computations

Use `either` to race two computations and get the first successful result:

```dart
final slow = delayedCont(Duration(seconds: 2), 42);
final fast = delayedCont(Duration(milliseconds: 100), 10);

Cont.either(
  slow,
  fast,
  policy: ContEitherPolicy.quitFast(), // Returns first success
).run((), onThen: print); // prints: 10 (fast wins)
```

You can also use the instance method `or` as a more fluent alternative:

```dart
final slow = delayedCont(Duration(seconds: 2), 42);
final fast = delayedCont(Duration(milliseconds: 100), 10);

slow.or(
  fast,
  policy: ContEitherPolicy.quitFast(),
).run((), onThen: print); // prints: 10 (fast wins)
```

Use `any` to race multiple computations:

```dart
final computations = [
  delayedCont(Duration(seconds: 2), 1),
  delayedCont(Duration(milliseconds: 100), 2),
  delayedCont(Duration(seconds: 1), 3),
];

Cont.any(
  computations,
  policy: ContEitherPolicy.quitFast(),
).run((), onThen: print); // prints: 2 (fastest)
```

---

## Environment Management

Environment allows threading configuration, dependencies, or context through continuation chains without explicitly passing them.

### Accessing Environment

Use `Cont.ask` to retrieve the current environment:

```dart
final program = Cont.ask<Config>().thenDo((config) {
  return fetchFromApi(config.apiUrl);
});

program.run(
  Config(apiUrl: "https://api.example.com"),
  onThen: print,
);
```

### Scoping Environment

Use `scope` to provide an environment value:

```dart
final cont = Cont.ask<String>().thenMap((s) => s.toUpperCase());

final program = cont.scope("hello");

program.run(
  "ignored", // outer env doesn't matter
  onThen: print,
); // prints: HELLO
```

### Transforming Environment with local

The `local` operator lets you transform the environment before passing it to a continuation. This is useful when you need to adapt the environment type or modify its contents:

```dart
class DatabaseConfig {
  final String host;
  final int port;
  DatabaseConfig(this.host, this.port);
}

class AppConfig {
  final DatabaseConfig dbConfig;
  final String apiKey;
  AppConfig(this.dbConfig, this.apiKey);
}

// Operation that needs DatabaseConfig
final dbOperation = Cont.ask<DatabaseConfig>().thenDo((config) {
  return connectToDb(config.host, config.port);
});

// Run with AppConfig by extracting DatabaseConfig
final program = dbOperation.local<AppConfig>((appConfig) => appConfig.dbConfig);

program.run(
  AppConfig(DatabaseConfig('localhost', 5432), 'key123'),
  onThen: print,
);
```

**Difference from `scope`:**
- `scope(value)`: Replaces environment with a fixed value
- `local(f)`: Transforms the outer environment before passing it down
- `local0(f)`: Provides environment from zero-argument function

**Variants:** `local0`

**Use cases:**
- Adapting environment types (extracting sub-configurations)
- Adding context to environment (timestamps, request IDs)
- Environment middleware patterns

### WithEnv Variants

All chaining and error handling operators have `WithEnv` variants that provide access to the environment:

```dart
Cont.of(42).thenDoWithEnv((env, value) {
  return fetchWithConfig(env.apiUrl, value);
});
```

Available variants:
- `thenDoWithEnv`, `thenDoWithEnv0`
- `thenTapWithEnv`, `thenTapWithEnv0`
- `thenZipWithEnv`, `thenZipWithEnv0`
- `thenForkWithEnv`, `thenForkWithEnv0`
- `elseDoWithEnv`, `elseDoWithEnv0`
- `elseTapWithEnv`, `elseTapWithEnv0`
- `elseZipWithEnv`, `elseZipWithEnv0`
- `elseForkWithEnv`, `elseForkWithEnv0`

### Dependency Injection Patterns

Jerelo provides two powerful operators for dependency injection: `injectInto` and `injectedBy`. These enable patterns where the result of one continuation becomes the environment (dependencies) for another.

#### Using injectInto

The `injectInto` method takes the value produced by one continuation and injects it as the environment for another continuation:

```dart
// Build a configuration and inject it into operations that need it
final configCont = Cont.of<(), DbConfig>(
  DbConfig(host: 'localhost', port: 5432)
);

// Define an operation that requires DbConfig as its environment
final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// Inject the config into the query operation
final result = configCont.injectInto(queryOp);
// Type: Cont<(), List<User>>

result.run((), onThen: (users) {
  print("Fetched ${users.length} users");
});
```

**Type transformation:**
- Input: `Cont<E, A>` (produces value of type `A`)
- Target: `Cont<A, A2>` (needs environment of type `A`)
- Output: `Cont<E, A2>` (produces value of type `A2` with original environment)

#### Using injectedBy

The `injectedBy` method is the inverse - it expresses that a continuation receives its environment from another source. This is equivalent to `cont.injectInto(this)` but reads more naturally:

```dart
// An operation that needs a database config
final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// A provider that produces the config
final configProvider = Cont.of<(), DbConfig>(
  DbConfig(host: 'localhost', port: 5432)
);

// Express that queryOp is injected by configProvider
final result = queryOp.injectedBy(configProvider);
// Type: Cont<(), List<User>>
```

#### Dependency Injection Use Cases

These operators are particularly useful for:

**1. Resource creation and injection:**

```dart
// Create a connection pool and inject it into operations
final poolCont = createConnectionPool(maxConnections: 10);

final transaction = Cont.ask<ConnectionPool>()
  .thenDo((pool) => pool.beginTransaction())
  .thenDo((txn) => performDatabaseWork(txn))
  .thenTap((result) => commitTransaction());

final program = poolCont.injectInto(transaction);
```

**2. Multi-stage dependency construction:**

```dart
// Build dependencies in stages
final httpClientCont = Cont.of(HttpClient(timeout: Duration(seconds: 5)));

final authServiceCont = httpClientCont.thenDo((client) {
  return Cont.of(AuthService(client: client, apiKey: 'secret'));
});

final userServiceOp = Cont.ask<AuthService>().thenDo((auth) {
  return fetchAuthenticatedUsers(auth);
});

// Inject the multi-stage dependency
final result = authServiceCont.injectInto(userServiceOp);
```

**3. Configuration scoping:**

```dart
// Different operations with different configs
class DatabaseConfig {
  final String host;
  final int port;
  DatabaseConfig(this.host, this.port);
}

class ApiConfig {
  final String baseUrl;
  final String apiKey;
  ApiConfig(this.baseUrl, this.apiKey);
}

// Operation needing DB config
final dbOp = Cont.ask<DatabaseConfig>().thenDo((config) {
  return queryDatabase(config.host, config.port);
});

// Operation needing API config
final apiOp = Cont.ask<ApiConfig>().thenDo((config) {
  return fetchFromApi(config.baseUrl, config.apiKey);
});

// Build and inject different configs
final dbConfig = Cont.of<(), DatabaseConfig>(
  DatabaseConfig('localhost', 5432)
);
final apiConfig = Cont.of<(), ApiConfig>(
  ApiConfig('https://api.example.com', 'key123')
);

// Each operation gets its own config type
final dbResult = dbConfig.injectInto(dbOp);   // Cont<(), DbData>
final apiResult = apiConfig.injectInto(apiOp); // Cont<(), ApiData>

// Combine them
Cont.both(
  dbResult,
  apiResult,
  (dbData, apiData) => merge(dbData, apiData),
  policy: ContBothPolicy.quitFast(),
).run((), onThen: print);
```

**4. Testing with mock dependencies:**

```dart
// Production code
final queryOp = Cont.ask<Database>().thenDo((db) {
  return db.query('SELECT * FROM users');
});

// Production: inject real database
final prodDb = Cont.of(RealDatabase());
final prodProgram = queryOp.injectedBy(prodDb);

// Testing: inject mock database
final mockDb = Cont.of(MockDatabase(testData: [...]));
final testProgram = queryOp.injectedBy(mockDb);
```

#### Key Benefits

- **Type-safe**: The compiler ensures environment types match correctly
- **Composable**: Chain multiple injection stages together
- **Flexible**: Use `injectInto` for forward declaration or `injectedBy` for reverse declaration
- **Testable**: Easy to swap implementations by injecting different providers
- **Clean**: No manual passing of dependencies through every function

---

## Creating Custom Extensions

Jerelo provides the building blocks for extending functionality through custom computations and operators. This section shows you how to create your own abstractions that integrate seamlessly with Jerelo's composition model.

### Custom Computations

The `Cont.fromRun` constructor gives you direct access to the runtime and observer, allowing you to create computations with custom execution logic.

**Basic anatomy:**

```dart
Cont<E, T> myComputation<E, T>() {
  return Cont.fromRun((runtime, observer) {
    // Your custom logic here

    try {
      // Perform computation
      final result = performWork();

      // Signal success
      observer.onThen(result);
    } catch (error, stackTrace) {
      // Signal termination
      observer.onElse([ContError.withStackTrace(error, stackTrace)]);
    }
  });
}
```

**Key rules when using `observer`:**

1. **Call exactly once**: You must call either `observer.onThen` or `observer.onElse` exactly once
2. **Idempotent**: Calling more than once has no effect (the first call wins)
3. **Mandatory**: Failing to call the observer results in undefined behavior and lost errors (with exception to cancallation cases)

**Example: Delayed computation**

```dart
Cont<E, T> delay<E, T>(Duration duration, T value) {
  return Cont.fromRun((runtime, observer) {
    Timer(duration, () {
      observer.onThen(value);
    });
  });
}

// Usage
delay(Duration(seconds: 2), 42).run(
  (),
  onThen: (value) => print("Got $value after 2 seconds"),
);
```

**Example: Wrapping callback-based APIs**

```dart
Cont<E, String> readFile<E>(String path) {
  return Cont.fromRun((runtime, observer) {
    File(path).readAsString().then(
      (contents) => observer.onThen(contents),
      onError: (error, stackTrace) {
        observer.onElse([ContError.withStackTrace(error, stackTrace)]);
      },
    );
  });
}
```

### Custom Operators

You can create custom operators by combining existing Jerelo operators or by using `decor` for lower-level control.

**Approach 1: Compose existing operators**

Most custom operators can be built by composing existing ones:

```dart
extension MyContExtensions<E, T> on Cont<E, T> {
  // Retry a computation N times on failure
  Cont<E, T> retry(int maxAttempts) {
    if (maxAttempts <= 1) return this;

    return this.elseDo((errors) {
      return retry(maxAttempts - 1).elseDo((_) {
        // If all retries fail, return original errors
        return Cont.stop(errors);
      });
    });
  }

  // Execute with a timeout
  Cont<E, T> timeout(Duration duration, T defaultValue) {
    final timeoutCont = delay<E, T>(duration, defaultValue);

    return Cont.either(
      this,
      timeoutCont,
      policy: ContEitherPolicy.quitFast(),
    );
  }

  // Log value for debugging without changing it
  Cont<E, T> debug(String label) {
    return this.thenTap((value) {
      print("[$label] $value");
      return Cont.of(());
    });
  }
}

// Usage
getUserData(userId)
  .retry(3)
  .timeout(Duration(seconds: 5), User.empty())
  .debug("User fetched")
  .run((), onThen: print);
```

**Approach 2: Use `decor` for low-level control**

When you need to intercept or modify the execution flow itself, use `decor`:

```dart
extension TimingExtension<E, T> on Cont<E, T> {
  // Measure execution time
  Cont<E, (T, Duration)> timed() {
    return this.decor((run, runtime, observer) {
      final stopwatch = Stopwatch()..start();

      run(
        runtime,
        ContObserver(
          onThen: (value) {
            stopwatch.stop();
            observer.onThen((value, stopwatch.elapsed));
          },
          onElse: (errors) {
            stopwatch.stop();
            observer.onElse(errors);
          },
        ),
      );
    });
  }
}

// Usage
fetchData()
  .timed()
  .run((), onThen: (result) {
    final (data, duration) = result;
    print("Fetched in ${duration.inMilliseconds}ms: $data");
  });
```

**Approach 3: Combine both approaches**

```dart
extension AdvancedExtensions<E, T> on Cont<E, T> {
  // Retry with exponential backoff
  Cont<E, T> retryWithBackoff({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
  }) {
    Cont<E, T> attempt(int attemptsLeft, Duration currentDelay) {
      if (attemptsLeft <= 0) return this;

      return this.elseDo((errors) {
        return delay<E, void>(currentDelay, null)
          .thenDo((_) => attempt(
            attemptsLeft - 1,
            currentDelay * 2,
          ))
          .elseDo((_) => Cont.stop<T>(errors));
      });
    }

    return attempt(maxAttempts, initialDelay);
  }
}
```

### Cancellation with Runtime

The `runtime` parameter passed to `Cont.fromRun` provides access to cancellation state. This allows you to create computations that respect cancellation requests and clean up resources appropriately.

**Important: Cancellation behavior**

When a computation detects cancellation via `runtime.isCancelled()`, it must:
1. **Stop all work immediately**
2. **NOT call `observer.onThen()` or `observer.onElse()`** - cancelled computations do not emit anything
3. **Clean up any acquired resources**
4. **Return/exit silently**

Cancelled computations are effectively abandoned - they produce no result and no error. The consumer will not receive any callbacks.

**Checking cancellation:**

```dart
Cont<E, List<T>> processLargeDataset<E, T>(List<T> items) {
  return Cont.fromRun((runtime, observer) {
    final results = <T>[];

    for (final item in items) {
      // Check if computation was cancelled
      if (runtime.isCancelled()) {
        // Don't emit anything - just exit silently
        return;
      }

      results.add(processItem(item));
    }

    observer.onThen(results);
  });
}
```

**Cancellation with asynchronous work:**

```dart
Cont<E, String> longRunningFetch<E>(String url) {
  return Cont.fromRun((runtime, observer) {
    // Check before starting work
    if (runtime.isCancelled()) {
      return; // Exit without emitting anything
    }

    final request = http.get(Uri.parse(url));

    request.then(
      (response) {
        // Check again before processing response
        if (runtime.isCancelled()) {
          // Don't emit - computation was cancelled
          return;
        }
        observer.onThen(response.body);
      },
      onError: (error, st) {
        // Only emit errors if not cancelled
        if (!runtime.isCancelled()) {
          observer.onElse([ContError.withStackTrace(error, st)]);
        }
      },
    );
  });
}
```

**Best practices for cancellation:**

1. **Check frequently**: In long-running operations, check `runtime.isCancelled()` periodically
2. **Don't emit on cancellation**: Never call `observer.onThen()` or `observer.onElse()` when cancelled
3. **Clean up resources**: Release any acquired resources before exiting
4. **Exit silently**: Simply return from the function without emitting anything
5. **Check before emitting**: Always check cancellation status before calling observer methods, especially in async callbacks

**Example: Cancellable operation with resource cleanup**

```dart
Cont<E, Data> processWithCleanup<E>() {
  return Cont.fromRun((runtime, observer) {
    final resource = acquireExpensiveResource();

    try {
      // Perform work in chunks
      for (final chunk in workChunks) {
        if (runtime.isCancelled()) {
          // Clean up and exit without emitting
          resource.dispose();
          return;
        }

        processChunk(chunk, resource);
      }

      // Success - emit result
      observer.onThen(resource.extractData());
    } catch (error, st) {
      // Only emit error if not cancelled
      if (!runtime.isCancelled()) {
        observer.onElse([ContError.withStackTrace(error, st)]);
      }
    } finally {
      // Always clean up
      resource.dispose();
    }
  });
}
```

**Example: Cancellable polling**

```dart
Cont<E, T> pollUntil<E, T>({
  required Cont<E, T> computation,
  required bool Function(T) predicate,
  Duration interval = const Duration(seconds: 1),
  int maxAttempts = 10,
}) {
  return Cont.fromRun((runtime, observer) {
    int attempts = 0;

    void poll() {
      // Check cancellation - exit without emitting
      if (runtime.isCancelled()) {
        return;
      }

      if (attempts >= maxAttempts) {
        observer.onElse([
          ContError.capture("Max attempts reached")
        ]);
        return;
      }

      attempts++;

      computation.run(
        runtime.env(), // Forward environment
        onElse: (errors) {
          // Check cancellation before emitting errors
          if (!runtime.isCancelled()) {
            observer.onElse(errors);
          }
        },
        onThen: (value) {
          // Check cancellation before processing value
          if (runtime.isCancelled()) {
            return;
          }

          if (predicate(value)) {
            observer.onThen(value);
          } else {
            Timer(interval, poll);
          }
        },
      );
    }

    poll();
  });
}

// Usage
pollUntil(
  computation: checkJobStatus(jobId),
  predicate: (status) => status.isComplete,
  interval: Duration(seconds: 2),
  maxAttempts: 30,
).run((), onThen: (status) {
  print("Job completed: $status");
});
```

The runtime also provides access to the environment via `runtime.env()` and the panic handler via `runtime.onPanic`, which can be useful when forwarding context to nested computations within custom implementations.

---

## Complete Example

Here's a comprehensive example bringing it all together:

```dart
class AppConfig {
  final String apiUrl;
  final String cacheDir;
  final Duration timeout;

  AppConfig(this.apiUrl, this.cacheDir, this.timeout);
}

// Fetch user with retry and caching
Cont<AppConfig, User> getUser(String userId) {
  return Cont.ask<AppConfig>()
    .thenDoWithEnv((config, _) {
      // Try API first
      return fetchFromApi(config.apiUrl, userId, config.timeout)
        .thenIf((user) => user.isValid)
        .elseTapWithEnv((env, errors) {
          // Log errors in background
          return logToFile(env.cacheDir, errors);
        })
        .elseDoWithEnv((env, errors) {
          // Fallback to cache
          return loadFromCache(env.cacheDir, userId);
        });
    })
    .thenTapWithEnv((env, user) {
      // Update cache in background
      return saveToCache(env.cacheDir, user)
        .elseFork((_) => Cont.of(())); // ignore cache failures
    });
}

// Fetch multiple users in parallel
Cont<AppConfig, List<User>> getUsers(List<String> userIds) {
  final continuations = userIds.map((id) => getUser(id)).toList();
  return Cont.all(
    continuations,
    policy: ContBothPolicy.quitFast(), // Fails fast if any user fetch fails
  );
}

// Process users with resource management
Cont<AppConfig, Report> processUsers(List<String> userIds) {
  return Cont.bracket<AppConfig, Database, Report>(
    acquire: openDatabase(),
    release: (db) => closeDatabase(db),
    use: (db) {
      return getUsers(userIds)
        .thenDo((users) => processInDb(db, users))
        .thenDo((results) => generateReport(results))
        .thenWhile((report) => !report.isComplete)
        .thenTapWithEnv((env, report) {
          return notifyComplete(env.apiUrl, report);
        });
    },
  );
}

// Run the program
final config = AppConfig(
  "https://api.example.com",
  "/tmp/cache",
  Duration(seconds: 5),
);

final token = processUsers(['user1', 'user2', 'user3']).run(
  config,
  onElse: (errors) {
    print("Failed: ${errors.length} error(s)");
    for (final e in errors) {
      print("  ${e.error}");
    }
  },
  onThen: (report) {
    print("Success: $report");
  },
);

// Cancel the computation if needed (e.g., on shutdown)
// token.cancel();
```

This example demonstrates:
- Environment management (AppConfig)
- Error handling with fallbacks (elseDo)
- Side effects (thenTap, elseFork)
- Conditional execution (thenIf)
- Parallel execution with policies (Cont.all with ContBothPolicy.quitFast)
- Resource management (bracket)
- Looping (thenWhile)
- WithEnv variants for accessing config
- Cancellation via `ContCancelToken` returned by `run`

---

## API Reference

This section provides a complete reference of all public APIs in Jerelo, organized by category.

### Constructors and Factory Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `fromRun` | `Cont<E, A> fromRun(void Function(ContRuntime<E>, ContObserver<A>) run)` | Create a continuation from a run function |
| `of` | `Cont<E, A> of(A value)` | Create a continuation that immediately succeeds with a value |
| `stop` | `Cont<E, A> stop([List<ContError> errors])` | Create a continuation that immediately terminates with optional errors |
| `ask` | `Cont<E, E> ask<E>()` | Retrieve the current environment value |
| `fromDeferred` | `Cont<E, A> fromDeferred(Cont<E, A> Function() thunk)` | Lazily evaluate a continuation-returning function |
| `bracket` | `Cont<E, A> bracket({...})` | Manage resource lifecycle with guaranteed cleanup |

### Transform Operators

Transform values on the success channel using pure functions.

| Method | Description |
|--------|-------------|
| `thenMap(f)` | Transform value with function `A → A2` |
| `thenMap0(f)` | Transform with zero-argument function `() → A2` |
| `thenMapWithEnv(f)` | Transform with `(E, A) → A2` |
| `thenMapWithEnv0(f)` | Transform with `E → A2` |
| `thenMapTo(value)` | Replace value with constant |

### Chain Operators (Do)

Chain continuations based on the previous result (monadic bind).

| Method | Description |
|--------|-------------|
| `thenDo(f)` | Chain with `A → Cont<E, A2>` |
| `thenDo0(f)` | Chain with `() → Cont<E, A2>` |
| `thenDoWithEnv(f)` | Chain with `(E, A) → Cont<E, A2>` |
| `thenDoWithEnv0(f)` | Chain with `E → Cont<E, A2>` |

### Tap Operators

Execute side effects while preserving the original value.

| Method | Description |
|--------|-------------|
| `thenTap(f)` | Side effect with `A → Cont<E, _>`, returns original `A` |
| `thenTap0(f)` | Side effect with `() → Cont<E, _>` |
| `thenTapWithEnv(f)` | Side effect with `(E, A) → Cont<E, _>` |
| `thenTapWithEnv0(f)` | Side effect with `E → Cont<E, _>` |

### Zip Operators

Run and combine results from two continuations.

| Method | Description |
|--------|-------------|
| `thenZip(f, combine)` | Chain `A → Cont<E, A2>` and combine with `(A, A2) → A3` |
| `thenZip0(f, combine)` | Chain `() → Cont<E, A2>` and combine results |
| `thenZipWithEnv(f, combine)` | Chain `(E, A) → Cont<E, A2>` and combine |
| `thenZipWithEnv0(f, combine)` | Chain `E → Cont<E, A2>` and combine |

### Fork Operators

Fire-and-forget side effects (don't wait for completion).

| Method | Description |
|--------|-------------|
| `thenFork(f)` | Fire-and-forget with `A → Cont<E, _>` |
| `thenFork0(f)` | Fire-and-forget with `() → Cont<E, _>` |
| `thenForkWithEnv(f)` | Fire-and-forget with `(E, A) → Cont<E, _>` |
| `thenForkWithEnv0(f)` | Fire-and-forget with `E → Cont<E, _>` |

### Conditional Operators (If)

Filter or validate values based on predicates.

| Method | Description |
|--------|-------------|
| `thenIf(predicate)` | Succeed only if `A → bool` is true, else terminate |
| `thenIf0(predicate)` | Succeed only if `() → bool` is true |
| `thenIfWithEnv(predicate)` | Succeed only if `(E, A) → bool` is true |
| `thenIfWithEnv0(predicate)` | Succeed only if `E → bool` is true |

### Loop Operators (While/Until)

Repeatedly execute a continuation based on predicates.

| Method | Description |
|--------|-------------|
| `thenWhile(predicate)` | Loop while `A → bool` is true |
| `thenWhile0(predicate)` | Loop while `() → bool` is true |
| `thenWhileWithEnv(predicate)` | Loop while `(E, A) → bool` is true |
| `thenWhileWithEnv0(predicate)` | Loop while `E → bool` is true |
| `thenUntil(predicate)` | Loop until `A → bool` is true (inverse of while) |
| `thenUntil0(predicate)` | Loop until `() → bool` is true |
| `thenUntilWithEnv(predicate)` | Loop until `(E, A) → bool` is true |
| `thenUntilWithEnv0(predicate)` | Loop until `E → bool` is true |
| `forever()` | Loop indefinitely, returns `Cont<E, Never>` |

### Abort Operators

Force termination with computed errors.

| Method | Description |
|--------|-------------|
| `abort(f)` | Terminate with `A → List<ContError>` |
| `abort0(f)` | Terminate with `() → List<ContError>` |
| `abortWithEnv(f)` | Terminate with `(E, A) → List<ContError>` |
| `abortWithEnv0(f)` | Terminate with `E → List<ContError>` |
| `abortWith(errors)` | Terminate with fixed error list |

### Error Operators (elseDo)

Recover from termination by providing fallback continuations.

| Method | Description |
|--------|-------------|
| `elseDo(f)` | Recover with `List<ContError> → Cont<E, A>` |
| `elseDo0(f)` | Recover with `() → Cont<E, A>` |
| `elseDoWithEnv(f)` | Recover with `(E, List<ContError>) → Cont<E, A>` |
| `elseDoWithEnv0(f)` | Recover with `E → Cont<E, A>` |

### Error Map Operators

Transform errors while staying on the termination channel.

| Method | Description |
|--------|-------------|
| `elseMap(f)` | Transform errors with `List<ContError> → List<ContError>` |
| `elseMap0(f)` | Replace errors with `() → List<ContError>` |
| `elseMapWithEnv(f)` | Transform errors with `(E, List<ContError>) → List<ContError>` |
| `elseMapWithEnv0(f)` | Replace errors with `E → List<ContError>` |
| `elseMapTo(errors)` | Replace errors with fixed list |

### Error Tap Operators

Execute side effects on termination while preserving errors.

| Method | Description |
|--------|-------------|
| `elseTap(f)` | Side effect with `List<ContError> → Cont<E, _>` |
| `elseTap0(f)` | Side effect with `() → Cont<E, _>` |
| `elseTapWithEnv(f)` | Side effect with `(E, List<ContError>) → Cont<E, _>` |
| `elseTapWithEnv0(f)` | Side effect with `E → Cont<E, _>` |

### Error Zip Operators

Run fallback and combine errors from both attempts.

| Method | Description |
|--------|-------------|
| `elseZip(f)` | Run `List<ContError> → Cont<E, A>` and merge errors if both fail |
| `elseZip0(f)` | Run `() → Cont<E, A>` and merge errors if both fail |
| `elseZipWithEnv(f)` | Run `(E, List<ContError>) → Cont<E, A>` and merge errors |
| `elseZipWithEnv0(f)` | Run `E → Cont<E, A>` and merge errors |

### Error Fork Operators

Fire-and-forget error handlers.

| Method | Description |
|--------|-------------|
| `elseFork(f)` | Fire-and-forget with `List<ContError> → Cont<E, _>` |
| `elseFork0(f)` | Fire-and-forget with `() → Cont<E, _>` |
| `elseForkWithEnv(f)` | Fire-and-forget with `(E, List<ContError>) → Cont<E, _>` |
| `elseForkWithEnv0(f)` | Fire-and-forget with `E → Cont<E, _>` |

### Error Conditional Operators

Conditionally recover based on error predicates.

| Method | Description |
|--------|-------------|
| `elseIf(predicate, value)` | Recover with `value` if `List<ContError> → bool` is true |
| `elseIf0(predicate, value)` | Recover with `value` if `() → bool` is true |
| `elseIfWithEnv(predicate, value)` | Recover with `value` if `(E, List<ContError>) → bool` is true |
| `elseIfWithEnv0(predicate, value)` | Recover with `value` if `E → bool` is true |

### Error Loop Operators

Retry on termination based on error predicates.

| Method | Description |
|--------|-------------|
| `elseWhile(predicate)` | Retry while `List<ContError> → bool` is true |
| `elseWhile0(predicate)` | Retry while `() → bool` is true |
| `elseWhileWithEnv(predicate)` | Retry while `(E, List<ContError>) → bool` is true |
| `elseWhileWithEnv0(predicate)` | Retry while `E → bool` is true |
| `elseUntil(predicate)` | Retry until `List<ContError> → bool` is true |
| `elseUntil0(predicate)` | Retry until `() → bool` is true |
| `elseUntilWithEnv(predicate)` | Retry until `(E, List<ContError>) → bool` is true |
| `elseUntilWithEnv0(predicate)` | Retry until `E → bool` is true |

### Recovery Operators

Convenience operators for error recovery.

| Method | Description |
|--------|-------------|
| `recover(f)` | Recover with `List<ContError> → A` |
| `recover0(f)` | Recover with `() → A` |
| `recoverWithEnv(f)` | Recover with `(E, List<ContError>) → A` |
| `recoverWithEnv0(f)` | Recover with `E → A` |
| `recoverWith(value)` | Recover with constant value |

### Merge Operators

Run multiple continuations and combine their results.

| Method | Description |
|--------|-------------|
| `Cont.both(left, right, combine, policy)` | Run two continuations and combine results |
| `and(right, combine, policy)` | Instance method for `both` |
| `Cont.all(list, policy)` | Run list of continuations and collect results |

**Policies for both/all:**
- `ContBothPolicy.sequence()` - Run sequentially, stop on first failure
- `ContBothPolicy.mergeWhenAll()` - Run in parallel, wait for all, combine all errors
- `ContBothPolicy.quitFast()` - Run in parallel, quit on first failure

### Race Operators

Race multiple continuations for first success.

| Method | Description |
|--------|-------------|
| `Cont.either(left, right, policy)` | Race two continuations, return first success |
| `or(right, policy)` | Instance method for `either` |
| `Cont.any(list, policy)` | Race list of continuations, return first success |

**Policies for either/any:**
- `ContEitherPolicy.sequence()` - Try sequentially until one succeeds
- `ContEitherPolicy.mergeWhenAll(combine)` - Run in parallel, combine multiple successes
- `ContEitherPolicy.quitFast()` - Run in parallel, quit on first success

### Environment Operators

Manage environment threading and transformation.

| Method | Description |
|--------|-------------|
| `local(f)` | Transform environment with `E2 → E` before passing down |
| `local0(f)` | Provide environment from `() → E` |
| `scope(value)` | Replace environment with fixed value |
| `injectInto(cont)` | Inject value as environment for another continuation |
| `injectedBy(cont)` | Receive environment from another continuation's value |

### Execution Methods

Execute continuations and handle results.

| Method | Return Type | Description |
|--------|-------------|-------------|
| `run(env, {onPanic, onElse, onThen})` | `ContCancelToken` | Execute with callbacks for success/error, returns cancellation token |
| `ff(env, {onPanic})` | `void` | Fire-and-forget execution (no result callbacks, no cancellation) |
| `trap(env, {isCancelled, onPanic, onElse})` | `ContCancelToken` | Execute `Cont<E, Never>` with only error handler |

### Decorator Operator

Transform execution behavior.

| Method | Description |
|--------|-------------|
| `decor(f)` | Natural transformation over the run function |

### Extension Methods

Special operations on specific continuation types.

| Method | Applies To | Description |
|--------|-----------|-------------|
| `flatten()` | `Cont<E, Cont<E, A>>` | Flatten nested continuation structure |
| `absurd<A>()` | `Cont<E, Never>` | Convert never-producing continuation to any type |
| `trap(env, ...)` | `Cont<E, Never>` | Execute with only error handler |

### Supporting Types

#### ContError

| Method | Description |
|--------|-------------|
| `ContError.withStackTrace(error, st)` | Create with existing stack trace |
| `ContError.withNoStackTrace(error)` | Create with empty stack trace |
| `ContError.capture(error)` | Create and capture current stack trace |

#### ContCancelToken

| Method | Description |
|--------|-------------|
| `cancel()` | Request cancellation |
| `isCancelled()` | Check if cancelled |

#### ContObserver

| Method | Description |
|--------|-------------|
| `onThen(value)` | Emit success value (idempotent, call once) |
| `onElse(errors)` | Emit termination errors (idempotent, call once) |

#### ContRuntime

| Method | Description |
|--------|-------------|
| `env()` | Access current environment |
| `isCancelled()` | Check if execution was cancelled |
| `onPanic` | Access panic handler |

### Variant Patterns

Most operators follow consistent naming patterns for variants:

- **Base form**: `thenDo(f)` - Takes value parameter
- **0 form**: `thenDo0(f)` - Ignores value, zero-argument function
- **WithEnv form**: `thenDoWithEnv(f)` - Takes environment and value
- **WithEnv0 form**: `thenDoWithEnv0(f)` - Takes only environment

This pattern applies to:
- All `then*` operators (Do, Tap, Zip, Fork, If, While, Until, Map)
- All `else*` operators (Do, Map, Tap, Zip, Fork, If, While, Until)
- `abort*` operators
- `recover*` operators
