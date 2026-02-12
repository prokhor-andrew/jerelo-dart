[Home](../../README.md) > User Guide

# Racing and Merging

Combine multiple computations using `both`/`all` (all must succeed) or `either`/`any` (first success wins). Each requires an **execution policy**.

Real-world applications rarely perform a single task in isolation. You often need to fetch data from several sources at once, try multiple strategies until one works, or validate many fields simultaneously. Jerelo models all of these scenarios through two complementary concepts: **merging** (all computations must succeed) and **racing** (the first success wins). The execution policy you choose determines whether the work runs sequentially or in parallel — and what happens when something fails.

## Execution Policies

Every combinator needs an execution policy that controls concurrency and failure handling. Two policy types enforce type safety:
- **`ContBothPolicy`** — for `both`/`all` (handles error combining)
- **`ContEitherPolicy<A>`** — for `either`/`any` (handles result combining)

### ContBothPolicy (for `both` and `all`)

Use `ContBothPolicy` when every computation must succeed. The policy controls what happens when one or more computations fail — you can bail out immediately, or wait for all results so you can report every error at once.

- **`sequence()`** — Runs sequentially, stops on first failure.
- **`mergeWhenAll()`** — Runs in parallel, waits for all, concatenates errors.
- **`quitFast()`** — Runs in parallel, stops on first failure.

### ContEitherPolicy (for `either` and `any`)

Use `ContEitherPolicy` when you only need one computation to succeed. This is ideal for fallback chains, timeouts, and redundant requests where the fastest or first valid result is all you care about.

- **`sequence()`** — Runs sequentially until one succeeds or all fail.
- **`mergeWhenAll(combine)`** — Runs in parallel, waits for all, combines successes via `combine`.
- **`quitFast()`** — Runs in parallel, returns first success.

---

## Merging Computations

Merging runs multiple computations and combines their results into a single value. If any computation fails, the overall result is a failure — how that failure is reported depends on the policy you chose above.

### Two Computations (`both` / `and`)

```dart
Cont.both(
  Cont.of(10),
  Cont.of(20),
  (a, b) => a + b,
  policy: ContBothPolicy.quitFast(),
).run((), onThen: print); // prints: 30
```

Fluent alternative with `and`:

```dart
Cont.of(10).and(
  Cont.of(20),
  (a, b) => a + b,
  policy: ContBothPolicy.quitFast(),
).run((), onThen: print); // prints: 30
```

### Many Computations (`all`)

When you have more than two computations, use `all` to merge an entire list. The result is a `List` containing every individual value, preserving the original order.

```dart
Cont.all(
  [Cont.of(1), Cont.of(2), Cont.of(3)],
  policy: ContBothPolicy.quitFast(),
).run((), onThen: print); // prints: [1, 2, 3]
```

---

## Racing Computations

Racing pits computations against each other and keeps the first success. This is the natural fit for scenarios like timeouts, fallback strategies, and redundant network requests where latency matters more than completeness.

### Two Computations (`either` / `or`)

```dart
Cont.either(
  delayedCont(Duration(seconds: 2), 42),
  delayedCont(Duration(milliseconds: 100), 10),
  policy: ContEitherPolicy.quitFast(),
).run((), onThen: print); // prints: 10 (fast wins)
```

Fluent alternative with `or`:

```dart
delayedCont(Duration(seconds: 2), 42).or(
  delayedCont(Duration(milliseconds: 100), 10),
  policy: ContEitherPolicy.quitFast(),
).run((), onThen: print); // prints: 10 (fast wins)
```

### Many Computations (`any`)

Just like `all` generalises `both`, `any` generalises `either` to an arbitrary list of computations. The winner depends on the policy — `quitFast()` returns as soon as the first computation succeeds, while `sequence()` tries each one in order.

```dart
Cont.any(
  [
    delayedCont(Duration(seconds: 2), 1),
    delayedCont(Duration(milliseconds: 100), 2),
    delayedCont(Duration(seconds: 1), 3),
  ],
  policy: ContEitherPolicy.quitFast(),
).run((), onThen: print); // prints: 2 (fastest)
```

---

## Common Patterns

The examples below show how merging and racing apply to everyday tasks. Each pattern pairs a specific combinator with the policy that best fits the use case.

### Parallel Fetch with Fast Failure

Loading a dashboard often means fetching several resources at once. Using `all` with `quitFast()` fires every request in parallel and aborts the moment any single request fails — no point rendering a half-loaded page.

```dart
Cont.all(
  [fetchUser(userId), fetchUserPosts(userId), fetchUserFriends(userId)],
  policy: ContBothPolicy.quitFast(),
).thenMap((results) {
  return DashboardData(
    user: results[0] as User,
    posts: results[1] as List<Post>,
    friends: results[2] as List<User>,
  );
}).run((), onThen: displayDashboard);
```

### Fallback Chain

A classic pattern: try the cache first, fall back to the network, and if all else fails, return a default. Using `or` with `sequence()` ensures each step only runs when the previous one has failed.

```dart
fetchFromCache(key)
  .or(fetchFromNetwork(key), policy: ContEitherPolicy.sequence())
  .or(Cont.of(defaultValue), policy: ContEitherPolicy.sequence())
  .run((), onThen: print);
```

### Race with Timeout

Race an expensive operation against a timer. Whichever finishes first wins, giving you a clean way to enforce deadlines without external cancellation logic.

```dart
Cont.either(
  performExpensiveOperation(),
  delay(Duration(seconds: 5), TimeoutResult()),
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

### Validation with All Errors

When validating user input, you typically want to report every problem at once rather than stopping at the first one. Pairing `all` with `mergeWhenAll()` runs every validator in parallel and concatenates all errors so the user can fix them in a single pass.

```dart
Cont.all(
  [validateEmail(email), validatePassword(password), validateAge(age)],
  policy: ContBothPolicy.mergeWhenAll(),
).run(
  (),
  onElse: (errors) {
    for (final error in errors) {
      print("Validation error: ${error.error}");
    }
  },
  onThen: (_) => print("All validations passed"),
);
```

---

## Next Steps

- **[Environment Management](05-environment.md)** — Master configuration and dependency injection
- **[Extending Jerelo](06-extending.md)** — Create custom operators
