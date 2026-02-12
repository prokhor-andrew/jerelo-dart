[Home](../../README.md) > [Documentation](../README.md) > User Guide

# Advanced Operations: Merge & Execution Policies

This guide covers parallel execution, racing computations, and execution policies.

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

## Policy Selection Guide

### When to use ContBothPolicy

Use `ContBothPolicy` when you need **all computations to succeed**:

| Policy | Execution | Error Handling | Best For |
|--------|-----------|----------------|----------|
| `sequence()` | Sequential | Stop on first error | Ordered operations, resource constraints |
| `mergeWhenAll()` | Parallel | Collect all errors | Comprehensive error reporting |
| `quitFast()` | Parallel | Stop on first error | Fast failure detection |

**Example use cases:**
- Validating multiple fields (collect all validation errors with `mergeWhenAll()`)
- Fetching data from multiple sources (fail fast with `quitFast()`)
- Processing steps that must happen in order (`sequence()`)

### When to use ContEitherPolicy

Use `ContEitherPolicy` when you need **at least one computation to succeed**:

| Policy | Execution | Result Handling | Best For |
|--------|-----------|-----------------|----------|
| `sequence()` | Sequential | First success | Fallback chain, priority ordering |
| `mergeWhenAll(combine)` | Parallel | Combine successes | Aggregate multiple results |
| `quitFast()` | Parallel | First success | Fastest response wins |

**Example use cases:**
- Fallback data sources: try cache, then network, then default (`sequence()`)
- Race multiple mirrors for fastest response (`quitFast()`)
- Fetch from multiple sources and combine (`mergeWhenAll()`)

---

## Common Patterns

### Pattern 1: Parallel Fetch with Fast Failure

```dart
final user = fetchUser(userId);
final posts = fetchUserPosts(userId);
final friends = fetchUserFriends(userId);

Cont.all(
  [user, posts, friends],
  policy: ContBothPolicy.quitFast(),
).thenMap((results) {
  return DashboardData(
    user: results[0] as User,
    posts: results[1] as List<Post>,
    friends: results[2] as List<User>,
  );
}).run((), onThen: displayDashboard);
```

### Pattern 2: Fallback Chain

```dart
fetchFromCache(key)
  .or(
    fetchFromNetwork(key),
    policy: ContEitherPolicy.sequence(),
  )
  .or(
    Cont.of(defaultValue),
    policy: ContEitherPolicy.sequence(),
  )
  .run((), onThen: print);
```

### Pattern 3: Race with Timeout

```dart
final actualWork = performExpensiveOperation();
final timeout = delay(Duration(seconds: 5), TimeoutResult());

Cont.either(
  actualWork,
  timeout,
  policy: ContEitherPolicy.quitFast(),
).run(
  (),
  onThen: (result) {
    if (result is TimeoutResult) {
      print("Operation timed out");
    } else {
      print("Operation completed: $result");
    }
  },
);
```

### Pattern 4: Validation with All Errors

```dart
final validations = [
  validateEmail(email),
  validatePassword(password),
  validateAge(age),
];

Cont.all(
  validations,
  policy: ContBothPolicy.mergeWhenAll(), // Collect all validation errors
).run(
  (),
  onElse: (errors) {
    // Display all validation errors to user
    for (final error in errors) {
      print("Validation error: ${error.error}");
    }
  },
  onThen: (_) => print("All validations passed"),
);
```

---

## Next Steps

Now that you understand advanced operations, continue to:
- **[Environment Management](05-environment.md)** - Master configuration and dependency injection
- **[Extending Jerelo](06-extending.md)** - Create custom operators
- **[Complete Examples](07-examples.md)** - See comprehensive real-world patterns
- **[API Reference](../api/)** - Quick reference lookup
