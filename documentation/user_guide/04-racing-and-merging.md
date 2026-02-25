[Home](../../README.md) > User Guide

# Racing and Merging

Combine multiple computations using `both`/`all` (all must succeed) or `either`/`any` (first success wins). Each requires an **execution policy**.

Real-world applications rarely perform a single task in isolation. You often need to fetch data from several sources at once, try multiple strategies until one works, or validate many fields simultaneously. Jerelo models all of these scenarios through two complementary concepts: **merging** (all computations must succeed) and **racing** (the first success wins). The execution policy you choose determines whether the work runs sequentially or in parallel — and what happens when something fails.

## Execution Policies

### OkPolicy (for `both`, `all`, `either`, `any`)

Every combinator on the success/error channels needs an `OkPolicy<T>` that controls concurrency and failure handling.

- **`OkPolicy.sequence()`** — Runs sequentially, one after another.
- **`OkPolicy.quitFast()`** — Runs in parallel, stops on first decisive outcome.
- **`OkPolicy.runAll(combine, shouldFavorCrash:)`** — Runs in parallel, waits for all to complete, combines same-channel outcomes via `combine`. When `shouldFavorCrash` is `true`, a crash is preferred over a non-crash outcome when one side crashes.

### CrashPolicy (for `coalesce`, `converge`)

When combining crash paths, use a `CrashPolicy<F, A>`:

- **`CrashPolicy.sequence()`** — Runs sequentially; if both crash, produces a `MergedCrash`.
- **`CrashPolicy.quitFast()`** — Runs in parallel, propagates first crash immediately.
- **`CrashPolicy.runAll(shouldFavorElse:, combineElseVals:, combineThenVals:)`** — Runs in parallel, waits for all, coalesces crashes. When multiple non-crash outcomes occur, they are combined via the provided functions.

---

## Merging Computations

Merging runs multiple computations and combines their results into a single value. If any computation fails, the overall result is a failure — how that failure is reported depends on the policy.

### Two Computations (`both` / `and`)

```dart
Cont.both(
  Cont.of(10),
  Cont.of(20),
  (a, b) => a + b,
  policy: OkPolicy.quitFast<String>(),
).run(null, onThen: print); // prints: 30
```

Fluent alternative with `and`:

```dart
Cont.of(10).and(
  Cont.of(20),
  (a, b) => a + b,
  policy: OkPolicy.quitFast<String>(),
).run(null, onThen: print); // prints: 30
```

Note: The type parameter on `OkPolicy` is the **error type** `F` for `both`/`all` (since errors need to be combined when using `runAll`), and the **value type** `A` for `either`/`any` (since values need to be combined when using `runAll`).

### Many Computations (`all`)

When you have more than two computations, use `all` to merge an entire list. The result is a `List` containing every individual value, preserving the original order.

```dart
Cont.all(
  [Cont.of(1), Cont.of(2), Cont.of(3)],
  policy: OkPolicy.quitFast<String>(),
).run(null, onThen: print); // prints: [1, 2, 3]
```

---

## Racing Computations

Racing pits computations against each other and keeps the first success. This is the natural fit for scenarios like timeouts, fallback strategies, and redundant network requests where latency matters more than completeness.

### Two Computations (`either` / `or`)

`either` requires a `combine` function for merging errors when both computations fail. Each side can have a different error type, and you provide a function to combine them:

```dart
Cont.either<void, String, String, String, int>(
  delayedCont(Duration(seconds: 2), 42),
  delayedCont(Duration(milliseconds: 100), 10),
  (e1, e2) => '$e1; $e2', // combine errors if both fail
  policy: OkPolicy.quitFast(),
).run(null, onThen: print); // prints: 10 (fast wins)
```

Fluent alternative with `or`:

```dart
delayedCont(Duration(seconds: 2), 42).or(
  delayedCont(Duration(milliseconds: 100), 10),
  (e1, e2) => '$e1; $e2',
  policy: OkPolicy.quitFast(),
).run(null, onThen: print); // prints: 10 (fast wins)
```

### Many Computations (`any`)

`any` generalises `either` to an arbitrary list of computations. If all fail, errors are collected into a `List<F>`:

```dart
Cont.any(
  [
    delayedCont(Duration(seconds: 2), 1),
    delayedCont(Duration(milliseconds: 100), 2),
    delayedCont(Duration(seconds: 1), 3),
  ],
  policy: OkPolicy.quitFast(),
).run(null, onThen: print); // prints: 2 (fastest)
```

---

## Crash-Path Combinators

When you need to combine continuations specifically to coalesce their crash paths, use `coalesce` and `converge`.

### Two Computations (`coalesce` / `coalesceWith`)

Runs two continuations and coalesces their crash paths. If both crash, the crashes are combined according to the policy.

```dart
Cont.coalesce(
  riskyOperation1(),
  riskyOperation2(),
  policy: CrashPolicy.sequence<String, int>(),
).run(null, onThen: print);
```

Fluent alternative:

```dart
riskyOperation1().coalesceWith(
  riskyOperation2(),
  policy: CrashPolicy.sequence<String, int>(),
).run(null, onThen: print);
```

### Many Computations (`converge`)

Runs multiple continuations and converges their crash paths. If multiple crash, crashes are combined (into `MergedCrash` for sequence, `CollectedCrash` for runAll):

```dart
Cont.converge(
  [operation1(), operation2(), operation3()],
  policy: CrashPolicy.quitFast<String, int>(),
).run(null, onThen: print);
```

---

## Common Patterns

### Parallel Fetch with Fast Failure

Loading a dashboard often means fetching several resources at once. Using `all` with `quitFast()` fires every request in parallel and aborts the moment any single request fails.

```dart
Cont.all(
  [fetchUser(userId), fetchUserPosts(userId), fetchUserFriends(userId)],
  policy: OkPolicy.quitFast<String>(),
).thenMap((results) {
  return DashboardData(
    user: results[0] as User,
    posts: results[1] as List<Post>,
    friends: results[2] as List<User>,
  );
}).run(null, onThen: displayDashboard);
```

### Fallback Chain

Try the cache first, fall back to the network, and if all else fails, return a default. Using `or` with `sequence()` ensures each step only runs when the previous one has failed.

```dart
fetchFromCache(key)
  .or(fetchFromNetwork(key), (e1, e2) => '$e1; $e2', policy: OkPolicy.sequence())
  .or(Cont.of(defaultValue), (e1, e2) => '$e1; $e2', policy: OkPolicy.sequence())
  .run(null, onThen: print);
```

### Race with Timeout

Race an expensive operation against a timer. Whichever finishes first wins.

```dart
Cont.either(
  performExpensiveOperation(),
  delay(Duration(seconds: 5), TimeoutResult()),
  (e1, e2) => '$e1; $e2',
  policy: OkPolicy.quitFast(),
).run(
  null,
  onThen: (result) {
    if (result is TimeoutResult) {
      print("Operation timed out");
    } else {
      print("Operation completed: $result");
    }
  },
);
```

### Validation with All Errors

When validating user input, you typically want to report every problem at once. Pairing `all` with `runAll()` runs every validator in parallel and combines all errors.

```dart
Cont.all(
  [validateEmail(email), validatePassword(password), validateAge(age)],
  policy: OkPolicy.runAll<String>(
    (e1, e2) => '$e1; $e2',
    shouldFavorCrash: false,
  ),
).run(
  null,
  onElse: (error) => print("Validation errors: $error"),
  onThen: (_) => print("All validations passed"),
);
```

---

## Next Steps

- **[Environment Management](05-environment.md)** — Master configuration and dependency injection
- **[Extending Jerelo](06-extending.md)** — Create custom operators
