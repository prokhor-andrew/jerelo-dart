[Home](../../README.md) > API Reference > Combining Continuations

# Combining Continuations

Parallel execution and combination of multiple continuations.

---

## Table of Contents

- [Policies](#policies)
  - [OkPolicy](#okpolicy)
  - [CrashPolicy](#crashpolicy)
- [Static Combinators](#static-combinators)
  - [Cont.both](#contboth)
  - [Cont.all](#contall)
  - [Cont.either](#conteither)
  - [Cont.any](#contany)
  - [Cont.coalesce](#contcoalesce)
  - [Cont.converge](#contconverge)
- [Instance Methods](#instance-methods)
  - [and](#and)
  - [or](#or)
  - [coalesceWith](#coalescewith)

---

## Policies

### OkPolicy

```dart
sealed class OkPolicy<T>
```

Execution policy for `both`/`all` (where `T` is the error type) and `either`/`any` (where `T` is the success type) operations.

Defines how multiple continuations should be executed. Different policies provide different trade-offs between execution order, error handling, and result combination.

**Static Factory Methods:**

```dart
static OkPolicy<T> sequence<T>()
```
Creates a sequential execution policy. Operations are executed one after another in order.

When used with `both`/`all`: execution stops at the first failure.
When used with `either`/`any`: execution stops at the first success.

Use this when:
- Order of execution matters
- You want to minimize resource usage by stopping early
- Later operations depend on side effects of earlier ones

**Example:**
```dart
final result = Cont.all(
  [operation1, operation2, operation3],
  policy: OkPolicy.sequence(),
);
```

---

```dart
static OkPolicy<T> quitFast<T>()
```
Creates a quit-fast policy. All operations start executing in parallel and the result is returned as soon as the decisive outcome occurs.

When used with `both`/`all`: returns immediately on the first failure.
When used with `either`/`any`: returns immediately on the first success.

Use this when:
- You want the fastest possible feedback
- A single decisive outcome is sufficient
- The cost of waiting for other operations is high

**Example:**
```dart
final result = Cont.both(
  checkPrimaryDb,
  checkSecondaryDb,
  (a, b) => (a, b),
  policy: OkPolicy.quitFast(),
);
```

---

```dart
static OkPolicy<T> runAll<T>(
  T Function(T t1, T t2) combine, {
  required bool shouldFavorCrash,
})
```
Creates a run-all policy. All operations execute in parallel and all must complete before a result is determined.

When used with `both`/`all`: waits for all continuations to complete; if multiple fail, their error values are combined using `combine`.
When used with `either`/`any`: waits for all continuations to complete; if multiple succeed, their values are combined using `combine`.

The `shouldFavorCrash` flag determines behavior when both crashes and non-crash outcomes exist:
- `true`: If any continuation crashes, the combined result is a crash (even if others succeeded/failed normally)
- `false`: Non-crash outcomes take priority over crashes

- **Parameters:**
  - `combine`: Function to merge two values of the decisive channel
  - `shouldFavorCrash`: Whether crashes take priority over non-crash outcomes

**Example:**
```dart
final result = Cont.all(
  [validateEmail, validatePassword, validateAge],
  policy: OkPolicy.runAll(
    (e1, e2) => '$e1; $e2',
    shouldFavorCrash: true,
  ),
);
```

**Policy Subtypes:**

| Subtype | Description |
|---|---|
| `SequenceOkPolicy<T>` | Sequential execution |
| `QuitFastOkPolicy<T>` | Parallel with fast termination |
| `RunAllOkPolicy<T>` | Parallel, wait for all, merge results |

---

### CrashPolicy

```dart
sealed class CrashPolicy<E, A>
```

Execution policy for `coalesce` and `converge` operations.

Defines how multiple continuations should be executed and how their crashes and non-crash outcomes should be combined. Unlike `OkPolicy` which focuses on one "ok" channel, `CrashPolicy` handles crash merging plus both error and success channels.

**Type Parameters:**
- `E`: The error type
- `A`: The success type

**Static Factory Methods:**

```dart
static CrashPolicy<E, A> sequence<E, A>()
```
Creates a sequential execution policy. Operations execute one after another.

---

```dart
static CrashPolicy<E, A> quitFast<E, A>()
```
Creates a quit-fast policy. All operations start in parallel; returns immediately on the first non-crash outcome.

---

```dart
static CrashPolicy<E, A> runAll<E, A>({
  required bool shouldFavorElse,
  required E Function(E e1, E e2) combineElseVals,
  required A Function(A a1, A a2) combineThenVals,
})
```
Creates a run-all policy. All operations execute in parallel and all must complete.

When multiple non-crash outcomes exist, `shouldFavorElse` determines whether errors or successes take priority:
- `true`: If any continuation fails with a typed error, the combined result is an error
- `false`: If any continuation succeeds, the combined result is a success

- **Parameters:**
  - `shouldFavorElse`: Whether errors take priority over successes
  - `combineElseVals`: Function to merge two error values
  - `combineThenVals`: Function to merge two success values

**Example:**
```dart
final result = Cont.coalesce(
  primarySource,
  backupSource,
  policy: CrashPolicy.runAll(
    shouldFavorElse: false,
    combineElseVals: (e1, e2) => '$e1; $e2',
    combineThenVals: (a1, a2) => a1 + a2,
  ),
);
```

**Policy Subtypes:**

| Subtype | Description |
|---|---|
| `SequenceCrashPolicy<E, A>` | Sequential execution |
| `QuitFastCrashPolicy<E, A>` | Parallel with fast termination |
| `RunAllCrashPolicy<E, A>` | Parallel, wait for all, merge results |

---

## Static Combinators

### Cont.both

```dart
static Cont<E, F, A3> both<E, F, A1, A2, A3>(
  Cont<E, F, A1> left,
  Cont<E, F, A2> right,
  A3 Function(A1 a, A2 a2) combine, {
  required OkPolicy<F> policy,
})
```

Runs two continuations and combines their successful results.

Both continuations must succeed for the result to be successful. If either fails, the entire operation fails. When both succeed, their values are combined using `combine`. The policy determines execution strategy and how errors are handled.

- **Parameters:**
  - `left`: First continuation to execute
  - `right`: Second continuation to execute
  - `combine`: Function to combine both successful values
  - `policy`: Execution policy (`OkPolicy<F>` — the error type determines how errors are merged)

**Example:**
```dart
final result = Cont.both(
  fetchUser(userId),
  fetchPosts(userId),
  (user, posts) => UserWithPosts(user, posts),
  policy: OkPolicy.quitFast(),
);
```

---

### Cont.all

```dart
static Cont<E, F, List<A>> all<E, F, A>(
  List<Cont<E, F, A>> list, {
  required OkPolicy<F> policy,
})
```

Runs multiple continuations and collects all results.

All continuations must succeed. The policy determines execution strategy and error handling.

- **Parameters:**
  - `list`: List of continuations to execute
  - `policy`: Execution policy

**Example:**
```dart
final validations = Cont.all(
  [validateEmail(email), validatePassword(password), validateAge(age)],
  policy: OkPolicy.runAll(
    (e1, e2) => '$e1; $e2',
    shouldFavorCrash: true,
  ),
);
```

---

### Cont.either

```dart
static Cont<E, F3, A> either<E, F1, F2, F3, A>(
  Cont<E, F1, A> left,
  Cont<E, F2, A> right,
  F3 Function(F1, F2) combine, {
  required OkPolicy<A> policy,
})
```

Races two continuations, returning the first successful value.

If both fail, their errors are combined using `combine`. The left and right continuations may have different error types, which are unified into `F3` by the combiner. The policy determines execution strategy and how successes are handled.

- **Parameters:**
  - `left`: First continuation to try
  - `right`: Second continuation to try
  - `combine`: Function to combine both error values if both fail
  - `policy`: Execution policy (`OkPolicy<A>` — the success type determines how successes are merged)

**Example:**
```dart
final data = Cont.either(
  fetchFromPrimary,
  fetchFromBackup,
  (err1, err2) => '$err1 and $err2',
  policy: OkPolicy.sequence(),
);
```

---

### Cont.any

```dart
static Cont<E, List<F>, A> any<E, F, A>(
  List<Cont<E, F, A>> list, {
  required OkPolicy<A> policy,
})
```

Races multiple continuations, returning the first successful value.

If all fail, collects all errors into a list. The policy determines execution strategy and how successes are handled.

- **Parameters:**
  - `list`: List of continuations to race
  - `policy`: Execution policy

**Example:**
```dart
final data = Cont.any(
  [fetchFromCache, fetchFromPrimaryDb, fetchFromBackupDb],
  policy: OkPolicy.quitFast(),
);
// On failure, errors are List<F>
```

---

### Cont.coalesce

```dart
static Cont<E, F, A> coalesce<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right, {
  required CrashPolicy<F, A> policy,
})
```

Runs two continuations and coalesces their crash paths.

Executes both continuations and combines crashes according to the `policy`. Non-crash outcomes (success and error) are handled according to the policy when both continuations produce them.

The execution behavior depends on the provided `policy`:

- **`SequenceCrashPolicy`**: Runs `left` then `right` sequentially; if both crash, produces a `MergedCrash`.
- **`QuitFastCrashPolicy`**: Runs both in parallel, propagates the first crash immediately.
- **`RunAllCrashPolicy`**: Runs both in parallel, waits for both, and coalesces crashes if both crash.

- **Parameters:**
  - `left`: First continuation to execute
  - `right`: Second continuation to execute
  - `policy`: Crash policy determining how crashes are coalesced

**Example:**
```dart
final result = Cont.coalesce(
  primarySource,
  backupSource,
  policy: CrashPolicy.quitFast(),
);
```

---

### Cont.converge

```dart
static Cont<E, F, A> converge<E, F, A>(
  List<Cont<E, F, A>> list, {
  required CrashPolicy<F, A> policy,
})
```

Runs multiple continuations and converges their crash paths.

Executes all continuations in `list` and combines their crashes according to the `policy`. Non-crash outcomes are handled per-policy when produced by multiple continuations.

The execution behavior depends on the provided `policy`:

- **`SequenceCrashPolicy`**: Runs continuations one by one; sequential crashes are converged into a `MergedCrash`.
- **`QuitFastCrashPolicy`**: Runs all in parallel, propagates the first crash immediately.
- **`RunAllCrashPolicy`**: Runs all in parallel, waits for all, and collects crashes into a `CollectedCrash`.

- **Parameters:**
  - `list`: List of continuations to execute
  - `policy`: Crash policy determining how crashes are converged

**Example:**
```dart
final result = Cont.converge(
  [source1, source2, source3],
  policy: CrashPolicy.sequence(),
);
```

---

## Instance Methods

### and

```dart
Cont<E, F, A3> and<A2, A3>(
  Cont<E, F, A2> right,
  A3 Function(A a, A2 a2) combine, {
  required OkPolicy<F> policy,
})
```

Instance method wrapper for `Cont.both`. Executes this continuation and `right` according to the specified `policy`, then combines their values.

- **Parameters:**
  - `right`: The other continuation to combine with
  - `combine`: Function to combine both successful values
  - `policy`: Execution policy

**Example:**
```dart
final result = fetchUser(userId).and(
  fetchPosts(userId),
  (user, posts) => UserWithPosts(user, posts),
  policy: OkPolicy.quitFast(),
);
```

---

### or

```dart
Cont<E, F3, A> or<F2, F3>(
  Cont<E, F2, A> right,
  F3 Function(F, F2) combine, {
  required OkPolicy<A> policy,
})
```

Instance method wrapper for `Cont.either`. Races this continuation against `right`, returning the first successful value. If both fail, errors are combined using `combine`.

- **Parameters:**
  - `right`: The other continuation to race with
  - `combine`: Function to combine error values if both fail
  - `policy`: Execution policy

**Example:**
```dart
final data = fetchFromPrimary.or(
  fetchFromBackup,
  (e1, e2) => '$e1; $e2',
  policy: OkPolicy.sequence(),
);
```

---

### coalesceWith

```dart
Cont<E, F, A> coalesceWith(
  Cont<E, F, A> right, {
  required CrashPolicy<F, A> policy,
})
```

Instance method wrapper for `Cont.coalesce`. Executes this continuation and `right` according to the specified `policy`, coalescing crashes when both crash.

- **Parameters:**
  - `right`: The other continuation whose crash path is coalesced
  - `policy`: Crash policy determining how crashes are coalesced

**Example:**
```dart
final result = primarySource.coalesceWith(
  backupSource,
  policy: CrashPolicy.quitFast(),
);
```
