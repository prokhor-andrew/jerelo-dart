
# Jerelo: Complete Feature Guide

This guide provides comprehensive coverage of every feature in Jerelo.
For conceptual introduction, see [doc.md](doc.md).

# Table of Contents

1. [Core Types](#core-types)
2. [Construction](#construction)
3. [Execution](#execution)
4. [Transformation](#transformation)
5. [Chaining](#chaining)
6. [Error Handling](#error-handling)
7. [Environment Management](#environment-management)
8. [WithEnv Variants](#withenv-variants)
9. [Parallel Execution](#parallel-execution)
10. [Execution Policies](#execution-policies)
11. [Branching and Looping](#branching-and-looping)
12. [Resource Management](#resource-management)
13. [Extensions](#extensions)
14. [Support Types](#support-types)

---

# Core Types

## Cont<E, A>

The main continuation monad. `E` is the environment type providing context,
and `A` is the value type produced upon success.

```dart
// Cont<Unit, int> - produces int, no environment needed
final computation = Cont.of(42);

// Cont<Config, User> - produces User, needs Config environment
final getUser = Cont.ask<Config>().thenDo((config) {
  return fetchUserFromDb(config.dbUrl);
});
```

## ContError

Immutable error container that wraps an error with its stack trace.

```dart
final error = ContError(
  Exception("Network failure"),
  StackTrace.current,
);
```

## ContRuntime<E>

Provides runtime context during execution:
- Access to environment via `env()`
- Cancellation checking via `isCancelled()`

## ContObserver<A>

Handles computation results:
- `onValue(A value)` - called on success
- `onTerminate([List<ContError> errors])` - called on failure

---

# Construction

## Cont.fromRun

Base constructor for custom computations. Provides automatic exception catching
and idempotent observer callbacks.

```dart
Cont<Unit, int> randomNumber() {
  return Cont.fromRun((runtime, observer) {
    try {
      final value = Random().nextInt(100);
      observer.onValue(value);
    } catch (error, st) {
      observer.onTerminate([ContError(error, st)]);
    }
  });
}
```

The observer is automatically guarded:
- Callbacks are idempotent (calling multiple times has no extra effect)
- Exceptions thrown in the run function are caught and converted to termination
- Cancellation is checked automatically

## Cont.fromDeferred

Defers construction of the inner continuation until execution.

```dart
Cont<Unit, User> getUserLazy() {
  return Cont.fromDeferred(() {
    // This expensive call only happens when the Cont is run
    final userId = computeExpensiveUserId();
    return getUser(userId);
  });
}
```

Useful when:
- Construction of the inner `Cont` is expensive
- You want to delay side effects until execution time
- The inner computation depends on values computed at runtime

## Cont.of

Wraps a pure value in a `Cont` context. The identity operation.

```dart
final cont = Cont.of(42); // Cont<E, int>

cont.run((), (_) {}, print); // prints: 42
```

## Cont.terminate

Creates a computation that immediately terminates with optional errors.

```dart
// Terminate with errors
final failed = Cont.terminate<Unit, int>([
  ContError("Not found", StackTrace.current),
]);

// Terminate with no errors (clean termination)
final stopped = Cont.terminate<Unit, int>();
```

## Cont.ask

Retrieves the current environment value.

```dart
Cont<Config, Config> getConfig() {
  return Cont.ask<Config>();
}

// Usage in a chain
final program = Cont.ask<Config>().thenDo((config) {
  return fetchData(config.apiUrl);
});
```

## Cont.bracket

Manages resources with guaranteed cleanup. See [Resource Management](#resource-management)
for details.

---

# Execution

## run

Executes the continuation with separate callbacks for termination and success.

```dart
final program = Cont.of(42).map((n) => n * 2);

program.run(
  (), // environment
  (errors) {
    print("Failed with ${errors.length} errors");
  },
  (value) {
    print("Success: $value"); // prints: Success: 84
  },
);
```

Parameters:
- `env` - Environment value to provide as context
- `onTerminate` - Callback for termination (errors)
- `onValue` - Callback for success

## ff (fire-and-forget)

Executes the continuation without waiting for results. Both success and
failure are ignored.

```dart
final logAction = Cont.fromRun((runtime, observer) {
  print("Background task");
  observer.onValue(());
});

// Start it and forget about it
logAction.ff(());

// Continues immediately without waiting
print("Moving on...");
```

Use cases:
- Fire-and-forget logging
- Background analytics
- Side effects that don't affect main flow
- Non-critical operations

---

# Transformation

## map

Transforms the success value using a pure function.

```dart
Cont.of(10)
  .map((n) => n * 2)
  .map((n) => n + 5)
  .run((), (_) {}, print); // prints: 25
```

If the function throws, it's caught and converted to termination:

```dart
Cont.of(10)
  .map((n) => throw Exception("Oops"))
  .run(
    (),
    (errors) => print("Caught: ${errors[0].error}"),
    (_) {},
  ); // prints: Caught: Exception: Oops
```

## map0

Transforms the value using a zero-argument function (ignores current value).

```dart
Cont.of(42)
  .map0(() => "hello")
  .run((), (_) {}, print); // prints: hello
```

Useful when:
- The new value doesn't depend on the old value
- You want to call a function for its return value
- Chaining with zero-argument functions

## as

Replaces the current value with a constant.

```dart
Cont.of(42)
  .as("done")
  .run((), (_) {}, print); // prints: done
```

Implemented as `map0(() => value)`. Useful for discarding intermediate
results while preserving the continuation chain.

## hoist

Transforms the underlying execution by wrapping the run function.
This is a powerful low-level operator for adding middleware-like behavior.

```dart
final cont = Cont.of(42);

// Add timing
final timed = cont.hoist((run, runtime, observer) {
  final start = DateTime.now();
  print('Starting execution...');

  run(runtime, observer);

  final elapsed = DateTime.now().difference(start);
  print('Execution initiated (took ${elapsed.inMilliseconds}ms)');
});

timed.run((), (_) {}, print);
// prints:
// Starting execution...
// Execution initiated (took 0ms)
// 42
```

Use cases:
- Logging execution start/end
- Profiling and timing
- Wrapping observers with custom behavior
- Scheduling and dispatching
- Adding debugging hooks

---

# Chaining

Chaining operators sequence computations where the next step depends on
the previous result.

## thenDo

Monadic bind. Chains a `Cont`-returning function.

```dart
Cont.of(5)
  .thenDo((n) => Cont.of(n * 2))
  .thenDo((n) => Cont.of(n + 3))
  .run((), (_) {}, print); // prints: 13
```

This is the fundamental composition operator. All other chaining operators
are built on top of `thenDo`.

## thenDo0

Chains a zero-argument `Cont`-returning function (ignores current value).

```dart
Cont.of(42)
  .thenDo0(() => Cont.of("next"))
  .run((), (_) {}, print); // prints: next
```

## thenTap

Executes a side-effect continuation while preserving the original value.

```dart
Cont.of(42)
  .thenTap((n) => logValue(n)) // side effect
  .map((n) => n * 2) // still has 42, not log result
  .run((), (_) {}, print); // prints: 84
```

The side-effect continuation is executed for its effects, then the original
value flows through.

## thenTap0

Zero-argument version of `thenTap`.

```dart
Cont.of(42)
  .thenTap0(() => logAction())
  .run((), (_) {}, print); // prints: 42
```

## thenZip

Chains and combines two continuation values.

```dart
Cont.of(5)
  .thenZip(
    (n) => Cont.of(n * 2), // produces 10
    (first, second) => first + second, // 5 + 10
  )
  .run((), (_) {}, print); // prints: 15
```

Execution flow:
1. First continuation produces value `a`
2. Second continuation (created from `a`) produces value `b`
3. Both values are combined using the `combine` function

## thenZip0

Zero-argument version of `thenZip` where the second continuation doesn't
depend on the first value.

```dart
Cont.of(5)
  .thenZip0(
    () => Cont.of(10),
    (first, second) => first + second,
  )
  .run((), (_) {}, print); // prints: 15
```

## thenFork

Executes a side-effect continuation in fire-and-forget manner.

```dart
Cont.of(42)
  .thenFork((n) => logInBackground(n)) // starts but doesn't wait
  .map((n) => n * 2) // continues immediately with 42
  .run((), (_) {}, print); // prints: 84
```

Unlike `thenTap`, this doesn't wait for the side-effect to complete:
- The side-effect starts immediately
- The main flow continues without waiting
- Any errors in the side-effect are silently ignored

## thenFork0

Zero-argument fire-and-forget side-effect.

```dart
Cont.of(42)
  .thenFork0(() => backgroundTask())
  .run((), (_) {}, print);
```

---

# Error Handling

Error handling operators work with the termination channel.

## elseDo

Provides a fallback continuation when termination occurs.

```dart
Cont.terminate<Unit, int>([ContError("fail", StackTrace.current)])
  .elseDo((errors) {
    print("Caught: ${errors[0].error}");
    return Cont.of(42); // recover
  })
  .run((), (_) {}, print); // prints: Caught: fail, then: 42
```

Important: If the fallback also fails, only the fallback's errors propagate:

```dart
Cont.terminate([error1])
  .elseDo((_) => Cont.terminate([error2]))
  .run(
    (),
    (errors) => print(errors.length), // prints: 1 (only error2)
    (_) {},
  );
```

To accumulate errors from both attempts, use `elseZip`.

## elseDo0

Zero-argument fallback (doesn't use error information).

```dart
Cont.terminate<Unit, int>()
  .elseDo0(() => Cont.of(0)) // default value
  .run((), (_) {}, print); // prints: 0
```

## elseTap

Executes a side-effect continuation on termination.

```dart
Cont.terminate([ContError("error", StackTrace.current)])
  .elseTap((errors) => logErrors(errors))
  .run(
    (),
    (errors) => print("Still failed"), // still terminates
    (_) {},
  );
```

**Important behavior**: If the side-effect succeeds, it can recover from
termination:

```dart
Cont.terminate<Unit, int>()
  .elseTap((_) => Cont.of(42)) // side effect succeeds
  .run((), (_) {}, print); // prints: 42 (recovered!)
```

If you want to always propagate the original termination, use `elseFork`.

## elseTap0

Zero-argument side-effect on termination.

```dart
Cont.terminate<Unit, int>()
  .elseTap0(() => cleanupAction())
  .run((), (e) => print("terminated"), (_) {});
```

## elseZip

Attempts a fallback and combines errors from both attempts if both fail.

```dart
Cont.terminate([error1])
  .elseZip(
    (_) => Cont.terminate([error2]),
    (errors1, errors2) => [...errors1, ...errors2], // accumulate
  )
  .run(
    (),
    (errors) => print(errors.length), // prints: 2
    (_) {},
  );
```

Unlike `elseDo` which only keeps the second error list, `elseZip` lets you
control how errors are combined.

## elseZip0

Zero-argument version of `elseZip`.

```dart
Cont.terminate([error1])
  .elseZip0(
    () => Cont.terminate([error2]),
    (e1, e2) => [...e1, ...e2],
  )
  .run((), (e) => print(e.length), (_) {}); // prints: 2
```

## elseFork

Executes a side-effect continuation on termination in fire-and-forget manner.

```dart
Cont.terminate([error])
  .elseFork((errors) => reportErrorsToAnalytics(errors))
  .run(
    (),
    (e) => print("Still fails"), // always terminates
    (_) {},
  );
```

Unlike `elseTap`, this always propagates the original termination, even if
the side-effect succeeds. The side-effect runs without waiting.

## elseFork0

Zero-argument fire-and-forget error handler.

```dart
Cont.terminate<Unit, int>()
  .elseFork0(() => backgroundErrorReport())
  .run((), (e) => print("terminated"), (_) {});
```

---

# Environment Management

Environment allows threading configuration, dependencies, or context through
continuation chains without explicitly passing them.

## Cont.ask

Retrieves the current environment value.

```dart
final program = Cont.ask<Config>().thenDo((config) {
  return fetchFromApi(config.apiUrl);
});

program.run(
  Config(apiUrl: "https://api.example.com"),
  (_) {},
  print,
);
```

## local

Transforms the environment for the current continuation.

```dart
final innerCont = Cont.ask<String>().map((s) => s.length);

final program = innerCont.local<int>((outerEnv) {
  return "Number: $outerEnv"; // int -> String
});

program.run(42, (_) {}, print); // prints: 10
```

The transformation function converts the outer environment type to the
inner type required by the continuation.

## local0

Provides a new environment from a zero-argument function.

```dart
final cont = Cont.ask<Config>().map((c) => c.apiUrl);

final program = cont.local0(() => Config(apiUrl: "test"));

program.run(
  (), // outer env ignored
  (_) {},
  print,
); // prints: test
```

## scope

Replaces the environment with a fixed value.

```dart
final cont = Cont.ask<String>().map((s) => s.toUpperCase());

final program = cont.scope("hello");

program.run(
  "ignored", // outer env doesn't matter
  (_) {},
  print,
); // prints: HELLO
```

This is the most common way to provide an environment value to a continuation
that needs it.

---

# WithEnv Variants

All chaining and error handling operators have `WithEnv` variants that provide
access to the environment. This allows computations to access configuration
or dependencies without using `Cont.ask` explicitly.

## thenDoWithEnv

Chains with access to both value and environment.

```dart
Cont.of(42).thenDoWithEnv((env, value) {
  return fetchWithConfig(env.apiUrl, value);
});
```

## thenDoWithEnv0

Chains with access to environment only (ignores value).

```dart
Cont.of(42).thenDoWithEnv0((env) {
  return getConfigValue(env);
});
```

## thenTapWithEnv / thenTapWithEnv0

Side effects with environment access.

```dart
Cont.of(42)
  .thenTapWithEnv((env, value) => logToFile(env.logPath, value))
  .run(config, (_) {}, print);
```

## thenZipWithEnv / thenZipWithEnv0

Combine two computations with environment access.

```dart
Cont.of(5)
  .thenZipWithEnv(
    (env, n) => fetchRemoteValue(env, n),
    (local, remote) => local + remote,
  )
  .run(config, (_) {}, print);
```

## thenForkWithEnv / thenForkWithEnv0

Fire-and-forget side effects with environment access.

```dart
Cont.of(42)
  .thenForkWithEnv((env, value) => reportToAnalytics(env, value))
  .run(config, (_) {}, print);
```

## elseDoWithEnv / elseDoWithEnv0

Error recovery with environment access.

```dart
Cont.terminate<Config, int>()
  .elseDoWithEnv((env, errors) {
    return loadFromCache(env.cacheDir);
  })
  .run(config, (_) {}, print);
```

## elseTapWithEnv / elseTapWithEnv0

Error side effects with environment access.

```dart
Cont.terminate([error])
  .elseTapWithEnv((env, errors) => logToFile(env.logPath, errors))
  .run(config, (e) => print("failed"), (_) {});
```

## elseZipWithEnv / elseZipWithEnv0

Error recovery with error combining and environment access.

```dart
Cont.terminate([error1])
  .elseZipWithEnv(
    (env, errors) => retryWithBackup(env.backupUrl),
    (e1, e2) => [...e1, ...e2],
  )
  .run(config, (e) => print(e.length), (_) {});
```

## elseForkWithEnv / elseForkWithEnv0

Fire-and-forget error handling with environment access.

```dart
Cont.terminate([error])
  .elseForkWithEnv((env, errors) => reportErrors(env, errors))
  .run(config, (e) => print("failed"), (_) {});
```

---

# Parallel Execution

Jerelo provides operators for running multiple continuations in parallel
with different coordination strategies.

## Cont.both

Runs two continuations and combines their results if both succeed.

```dart
final left = Cont.of(10);
final right = Cont.of(20);

Cont.both(
  left,
  right,
  (a, b) => a + b,
  policy: ContPolicy.quitFast(),
).run((), (_) {}, print); // prints: 30
```

Both continuations must succeed for the result to be successful.
If either fails, the entire operation fails.

Behavior depends on the policy:
- **SequencePolicy**: Runs left, then right sequentially
- **MergeWhenAllPolicy**: Runs both in parallel, waits for both, merges errors
- **QuitFastPolicy**: Runs both in parallel, quits on first failure

## and

Instance method wrapper for `both`.

```dart
Cont.of(10)
  .and(
    Cont.of(20),
    (a, b) => a + b,
    policy: ContPolicy.quitFast(),
  )
  .run((), (_) {}, print); // prints: 30
```

## Cont.all

Runs multiple continuations and collects all results.

```dart
final computations = [
  Cont.of(1),
  Cont.of(2),
  Cont.of(3),
];

Cont.all(
  computations,
  policy: ContPolicy.quitFast(),
).run((), (_) {}, print); // prints: [1, 2, 3]
```

All must succeed for the result to be successful. Returns a list of all values
in the same order as the input list.

Behavior depends on policy:
- **SequencePolicy**: Runs one by one in order, stops at first failure
- **MergeWhenAllPolicy**: Runs all in parallel, waits for all, merges errors
- **QuitFastPolicy**: Runs all in parallel, quits on first failure

## Cont.either

Races two continuations, returning the first successful value.

```dart
final slow = delayedCont(Duration(seconds: 2), 42);
final fast = delayedCont(Duration(milliseconds: 100), 10);

Cont.either(
  slow,
  fast,
  (errors1, errors2) => [...errors1, ...errors2],
  policy: ContPolicy.quitFast(),
).run((), (_) {}, print); // prints: 10 (fast wins)
```

Returns the first success. If both fail, combines errors using the provided
function.

Behavior depends on policy:
- **SequencePolicy**: Tries left, then right if left fails
- **MergeWhenAllPolicy**: Runs both, returns first success or merges results/errors
- **QuitFastPolicy**: Runs both, returns immediately on first success

## or

Instance method wrapper for `either`.

```dart
slowCont()
  .or(
    fastCont(),
    (e1, e2) => [...e1, ...e2],
    policy: ContPolicy.quitFast(),
  )
  .run((), (_) {}, print);
```

## Cont.any

Races multiple continuations, returning the first successful value.

```dart
final computations = [
  slowCont(5),
  fastCont(10),
  mediumCont(7),
];

Cont.any(
  computations,
  policy: ContPolicy.quitFast(),
).run((), (_) {}, print); // prints value from fastest cont
```

Returns the first success. If all fail, collects all errors.

Behavior depends on policy:
- **SequencePolicy**: Tries one by one in order until one succeeds
- **MergeWhenAllPolicy**: Runs all, returns first success or merges results
- **QuitFastPolicy**: Runs all, returns immediately on first success

---

# Execution Policies

Policies control how multiple continuations are executed and how their
results/errors are combined.

## ContPolicy<T>

Sealed class with three implementations:

### SequencePolicy

Executes operations one after another in order.

```dart
final policy = ContPolicy.sequence<List<ContError>>();

Cont.all(
  [cont1, cont2, cont3],
  policy: policy,
).run((), (_) {}, print);
// Runs cont1, then cont2, then cont3 in order
// Stops at first failure for 'all'
// Continues until success for 'any'
```

Use when:
- Order matters
- Want to avoid unnecessary work if early failure
- Sequential dependencies
- Simpler debugging (predictable execution order)

### MergeWhenAllPolicy

Executes all operations in parallel and waits for all to complete.
Results or errors are accumulated using a combiner function.

```dart
final policy = ContPolicy.mergeWhenAll<List<ContError>>(
  (acc, value) => [...acc, ...value],
);

Cont.all(
  [cont1, cont2, cont3],
  policy: policy,
).run((), (_) {}, print);
// Runs all three in parallel
// Waits for all to complete
// Merges all errors if any fail
```

The combiner receives:
- `acc` - The accumulated value so far
- `value` - The new value to merge

Use when:
- Want maximum parallelism
- Need to collect all results/errors
- Failures don't invalidate other results
- Better resource utilization

### QuitFastPolicy

Executes operations in parallel but terminates as soon as a decisive result
is reached.

```dart
final policy = ContPolicy.quitFast<List<ContError>>();

Cont.all(
  [cont1, cont2, cont3],
  policy: policy,
).run((), (_) {}, print);
// Runs all three in parallel
// For 'all': quits immediately on first failure
// For 'any': quits immediately on first success
```

Use when:
- Want fastest possible feedback
- Early failure/success is sufficient
- Don't need to accumulate all errors
- Optimizing for latency

## Choosing a Policy

| Scenario | Best Policy |
|----------|-------------|
| Must run in specific order | SequencePolicy |
| Want all errors even if some succeed | MergeWhenAllPolicy |
| Want fastest failure detection | QuitFastPolicy |
| Running expensive operations | QuitFastPolicy or Sequence |
| Need complete error reports | MergeWhenAllPolicy |
| Retry logic | SequencePolicy or QuitFastPolicy |

---

# Branching and Looping

## when

Filters based on a predicate. Succeeds if predicate returns `true`,
terminates if `false`.

```dart
Cont.of(5)
  .when((n) => n > 3)
  .run(
    (),
    (_) => print("terminated"),
    (n) => print("success: $n"),
  ); // prints: success: 5

Cont.of(2)
  .when((n) => n > 3)
  .run(
    (),
    (_) => print("terminated"), // prints: terminated
    (_) {},
  );
```

Use when:
- Conditional execution
- Early termination based on conditions
- Validation of intermediate results
- Treating predicate failure as clean termination (not an error)

## asLongAs

Repeatedly executes the continuation as long as the predicate returns `true`.

```dart
var counter = 0;

Cont.fromRun<Unit, int>((runtime, observer) {
  counter++;
  observer.onValue(counter);
})
  .asLongAs((n) => n < 5)
  .run(
    (),
    (_) {},
    (n) => print("Stopped at: $n"),
  ); // prints: Stopped at: 5
```

The loop:
- Executes the continuation
- Tests the result with the predicate
- If `true`, repeats
- If `false`, succeeds with that value

Stack-safe: Handles both synchronous and asynchronous continuations correctly
without stack overflow.

Use for:
- Retry logic with conditions
- Polling until state changes
- Repeating operations while a condition holds

## until

Repeatedly executes until the predicate returns `true` (inverse of `asLongAs`).

```dart
var counter = 0;

Cont.fromRun<Unit, int>((runtime, observer) {
  counter++;
  observer.onValue(counter);
})
  .until((n) => n >= 5) // inverted condition
  .run(
    (),
    (_) {},
    (n) => print("Reached: $n"),
  ); // prints: Reached: 5
```

Implemented as `asLongAs((a) => !predicate(a))`.

Use when:
- Retry until condition met
- Polling until ready
- More natural "keep going until done" semantics

## forever

Repeatedly executes indefinitely. Never produces a value.

```dart
final server = acceptConnection()
  .thenDo((conn) => handleConnection(conn))
  .forever();

server.trap((), (errors) {
  print("Server stopped: $errors");
});
// Runs forever unless an error occurs
```

Return type is `Cont<E, Never>`:
- Never produces a value (only terminates)
- Runs indefinitely until error
- Must use `.trap()` or provide no-op value callback

Use for:
- Server loops
- Event loops
- Daemon processes
- Background tasks that should never stop

---

# Resource Management

## Cont.bracket

Guarantees resource cleanup with a acquire-use-release pattern.

```dart
Cont.bracket<Unit, File, String>(
  acquire: Cont.fromRun((runtime, observer) {
    final file = File('data.txt').openSync();
    observer.onValue(file);
  }),
  release: (file) => Cont.fromRun((runtime, observer) {
    file.closeSync();
    observer.onValue(());
  }),
  use: (file) => Cont.fromRun((runtime, observer) {
    final contents = file.readStringSync();
    observer.onValue(contents);
  }),
).run((), (_) {}, print);
```

Execution order:
1. **acquire** - Obtain the resource
2. **use** - Use the resource to produce a value
3. **release** - Release the resource (always runs)

The `release` phase:
- **Always executes**, even if `use` fails
- Runs with a non-cancellable runtime (guaranteed cleanup)
- Executes even during cancellation

Error handling:
- Both succeed → returns value from `use`
- `use` succeeds, `release` fails → terminates with release errors
- `use` fails, `release` succeeds → terminates with use errors
- Both fail → terminates with combined errors

```dart
// Both succeed
Cont.bracket<Unit, Resource, int>(
  acquire: getResource(),
  release: (r) => closeResource(r), // succeeds
  use: (r) => Cont.of(42), // succeeds
); // produces 42

// Use succeeds, release fails
Cont.bracket<Unit, Resource, int>(
  acquire: getResource(),
  release: (r) => Cont.terminate([releaseError]), // fails
  use: (r) => Cont.of(42), // succeeds
); // terminates with releaseError

// Use fails, release succeeds
Cont.bracket<Unit, Resource, int>(
  acquire: getResource(),
  release: (r) => closeResource(r), // succeeds
  use: (r) => Cont.terminate([useError]), // fails
); // terminates with useError

// Both fail
Cont.bracket<Unit, Resource, int>(
  acquire: getResource(),
  release: (r) => Cont.terminate([releaseError]), // fails
  use: (r) => Cont.terminate([useError]), // fails
); // terminates with [useError, releaseError]
```

Use for:
- File handles
- Database connections
- Network sockets
- Locks and semaphores
- Any resource that needs cleanup

---

# Extensions

## ContFlattenExtension

Provides `flatten()` for nested continuations.

```dart
final nested = Cont.of(Cont.of(42)); // Cont<Unit, Cont<Unit, int>>

final flattened = nested.flatten(); // Cont<Unit, int>

flattened.run((), (_) {}, print); // prints: 42
```

Equivalent to `thenDo((cont) => cont)`.

Use when:
- Working with nested continuation structures
- After mapping with a function that returns `Cont`
- Simplifying deeply nested computations

## ContRunExtension

Provides `trap()` for `Cont<E, Never>`.

```dart
final neverProduces = Cont.terminate<Unit, Never>();

// Regular run requires a value callback (never called)
neverProduces.run((), (e) => print("error"), (_) {});

// trap() only requires termination callback
neverProduces.trap((), (e) => print("error"));
```

Use for continuations that:
- Use `forever()` and never produce values
- Represent infinite loops or servers
- Only terminate (never succeed)

---

# Support Types

## ContError

Wraps an error with its stack trace.

```dart
final error = ContError(
  Exception("Network timeout"),
  StackTrace.current,
);

print(error.error); // Exception: Network timeout
print(error.stackTrace); // stack trace
print(error); // { error=Exception: Network timeout, stackTrace=... }
```

Used throughout the library for consistent error propagation.

## ContRuntime<E>

Provides runtime context during continuation execution.

```dart
Cont.fromRun((runtime, observer) {
  // Access environment
  final env = runtime.env();
  print("Config: $env");

  // Check cancellation
  if (runtime.isCancelled()) {
    print("Cancelled, aborting");
    return;
  }

  observer.onValue(42);
});
```

Methods:
- `env()` - Returns the environment value
- `isCancelled()` - Returns true if execution should stop
- `copyUpdateEnv(newEnv)` - Creates copy with different environment

Used internally by `Cont` operators, rarely used directly in user code.

## ContObserver<A>

Handles continuation results with callbacks.

```dart
Cont.fromRun((runtime, observer) {
  try {
    final value = computeValue();
    observer.onValue(value);
  } catch (error, st) {
    observer.onTerminate([ContError(error, st)]);
  }
});
```

Methods:
- `onValue(value)` - Signal successful completion
- `onTerminate([errors])` - Signal termination with optional errors
- `copyUpdateOnValue(newCallback)` - Create copy with new value handler
- `copyUpdateOnTerminate(newCallback)` - Create copy with new termination handler

Properties:
- Idempotent: Calling multiple times has no extra effect
- Guarded: Automatically checked for cancellation
- One-shot: Only the first call matters

Used in `fromRun` constructor and internally by operators.

---

# Complete Example

Here's a comprehensive example showcasing many features:

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
        .when((user) => user.isValid)
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
    policy: ContPolicy.quitFast(),
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
        .asLongAs((report) => !report.isComplete)
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

processUsers(['user1', 'user2', 'user3']).run(
  config,
  (errors) {
    print("Failed: ${errors.length} error(s)");
    for (final e in errors) {
      print("  ${e.error}");
    }
  },
  (report) {
    print("Success: $report");
  },
);
```

This example demonstrates:
- Environment management (AppConfig)
- Error handling with fallbacks (elseDo)
- Side effects (thenTap, elseFork)
- Conditional execution (when)
- Parallel execution (Cont.all)
- Resource management (bracket)
- Looping (asLongAs)
- WithEnv variants for accessing config

---

# Quick Reference

## Construction
- `Cont.fromRun(run)` - Custom computation
- `Cont.fromDeferred(thunk)` - Lazy construction
- `Cont.of(value)` - Wrap value
- `Cont.terminate([errors])` - Immediate termination
- `Cont.ask()` - Get environment
- `Cont.bracket(acquire, release, use)` - Resource management

## Execution
- `cont.run(env, onTerminate, onValue)` - Execute
- `cont.ff(env)` - Fire-and-forget

## Transformation
- `cont.map(f)` - Transform value
- `cont.map0(f)` - Transform ignoring current value
- `cont.as(value)` - Replace with constant
- `cont.hoist(f)` - Transform execution

## Chaining (then family)
- `thenDo(f)` - Chain continuation
- `thenDo0(f)` - Chain ignoring value
- `thenTap(f)` - Side effect (wait)
- `thenTap0(f)` - Side effect (wait, ignore value)
- `thenZip(f, combine)` - Chain and combine
- `thenZip0(f, combine)` - Chain and combine (ignore value)
- `thenFork(f)` - Side effect (fire-and-forget)
- `thenFork0(f)` - Side effect (fire-and-forget, ignore value)

## Error Handling (else family)
- `elseDo(f)` - Fallback on termination
- `elseDo0(f)` - Fallback (ignore errors)
- `elseTap(f)` - Side effect on termination (can recover)
- `elseTap0(f)` - Side effect (ignore errors)
- `elseZip(f, combine)` - Fallback with error combining
- `elseZip0(f, combine)` - Fallback with combining (ignore errors)
- `elseFork(f)` - Side effect on termination (fire-and-forget)
- `elseFork0(f)` - Side effect (fire-and-forget, ignore errors)

## Environment
- `Cont.ask()` - Get environment
- `cont.local(f)` - Transform environment
- `cont.local0(f)` - Provide environment from function
- `cont.scope(value)` - Replace environment

## WithEnv Variants
All `then*` and `else*` operators have `*WithEnv` and `*WithEnv0` variants:
- `thenDoWithEnv(f)`, `thenDoWithEnv0(f)`
- `thenTapWithEnv(f)`, `thenTapWithEnv0(f)`
- `thenZipWithEnv(f, c)`, `thenZipWithEnv0(f, c)`
- `thenForkWithEnv(f)`, `thenForkWithEnv0(f)`
- `elseDoWithEnv(f)`, `elseDoWithEnv0(f)`
- `elseTapWithEnv(f)`, `elseTapWithEnv0(f)`
- `elseZipWithEnv(f, c)`, `elseZipWithEnv0(f, c)`
- `elseForkWithEnv(f)`, `elseForkWithEnv0(f)`

## Parallel Execution
- `Cont.both(left, right, combine, policy:)` - Two in parallel
- `cont.and(right, combine, policy:)` - Instance version of both
- `Cont.all(list, policy:)` - All in parallel
- `Cont.either(left, right, combine, policy:)` - Race two
- `cont.or(right, combine, policy:)` - Instance version of either
- `Cont.any(list, policy:)` - Race multiple

## Policies
- `ContPolicy.sequence()` - Sequential execution
- `ContPolicy.mergeWhenAll(combine)` - Parallel with merge
- `ContPolicy.quitFast()` - Parallel with early exit

## Branching/Looping
- `cont.when(predicate)` - Filter by condition
- `cont.asLongAs(predicate)` - Loop while true
- `cont.until(predicate)` - Loop until true
- `cont.forever()` - Loop indefinitely

## Extensions
- `nestedCont.flatten()` - Flatten nested continuations
- `neverCont.trap(env, onTerminate)` - Run Cont<E, Never>

---

For conceptual introduction and motivation, see [doc.md](doc.md).
