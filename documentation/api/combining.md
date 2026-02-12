[Home](../../README.md) > [Documentation](../README.md) > [API Reference](README.md)

# Combining Continuations

Parallel execution and combination of multiple continuations.

---

## Table of Contents

- [Policies](#policies)
  - [ContBothPolicy](#contbothpolicy)
  - [ContEitherPolicy](#conteitherpolicy)
- [Static Combinators](#static-combinators)
  - [Cont.both](#contboth)
  - [Cont.all](#contall)
  - [Cont.either](#conteither)
  - [Cont.any](#contany)
- [Instance Methods](#instance-methods)
  - [and](#and)
  - [or](#or)

---

## Policies

### ContBothPolicy

```dart
sealed class ContBothPolicy
```

Execution policy for `both` and `all` operations.

Defines how multiple continuations should be executed and how their errors should be combined when all operations must succeed. Different policies provide different trade-offs between execution order, error handling, and result combination.

**Available Policies:**
- [BothSequencePolicy](#bothsequencepolicy): Executes operations sequentially, one after another
- [BothMergeWhenAllPolicy](#bothmergewhenallpolicy): Waits for all operations to complete and merges errors if any fail
- [BothQuitFastPolicy](#bothquitfastpolicy): Terminates immediately on the first failure

**Static Factory Methods:**

```dart
static ContBothPolicy sequence()
```
Creates a sequential execution policy. Operations are executed one after another in order. Execution stops at the first failure.

When used with `both` or `all`:
- Continuations execute sequentially in the order provided
- If any continuation terminates, execution stops immediately
- Only the errors from the first failing continuation are propagated
- Guarantees that later continuations don't start if an earlier one fails

Use this when:
- Order of execution matters
- You want to minimize resource usage by stopping early
- Later operations depend on side effects of earlier ones

**Example:**
```dart
final result = Cont.all(
  [operation1, operation2, operation3],
  policy: ContBothPolicy.sequence(),
);
// Runs operation1, then operation2, then operation3
// Stops at first failure
```

---

```dart
static ContBothPolicy mergeWhenAll()
```
Creates a merge-when-all policy. All operations are executed in parallel and all must complete. Errors from all failed operations are concatenated into a single error list.

When used with `both` or `all`:
- All continuations start executing in parallel
- Waits for all continuations to complete (success or failure)
- If multiple continuations fail, all their errors are collected and concatenated
- All operations run to completion regardless of failures

Use this when:
- You want to collect all errors from all failed operations
- Operations are independent and can run in parallel
- You need comprehensive error information from all attempts

**Example:**
```dart
final result = Cont.all(
  [validateEmail, validatePassword, validateAge],
  policy: ContBothPolicy.mergeWhenAll(),
);
// Runs all validations in parallel
// Returns all validation errors if any fail
```

---

```dart
static ContBothPolicy quitFast()
```
Creates a quit-fast policy. Terminates immediately on the first failure. Provides the fastest feedback but may leave other operations running.

When used with `both` or `all`:
- All continuations start executing in parallel
- Returns immediately when the first continuation fails
- Only the errors from the first failing continuation are propagated
- Other operations may continue running in the background

Use this when:
- You want the fastest possible failure feedback
- A single failure is enough to determine overall failure
- The cost of waiting for other operations is high

**Example:**
```dart
final result = Cont.both(
  checkPrimaryDb,
  checkSecondaryDb,
  (a, b) => (a, b),
  policy: ContBothPolicy.quitFast(),
);
// Runs both checks in parallel
// Fails immediately if either fails
```

**Policy Type Details:**

#### BothSequencePolicy

```dart
final class BothSequencePolicy extends ContBothPolicy
```

Sequential execution policy for `both`/`all` operations.

Executes continuations one after another in order. Stops at the first failure.

#### BothMergeWhenAllPolicy

```dart
final class BothMergeWhenAllPolicy extends ContBothPolicy
```

Merge-when-all execution policy for `both`/`all` operations.

Executes all continuations in parallel and waits for all to complete. Concatenates errors if multiple operations fail.

#### BothQuitFastPolicy

```dart
final class BothQuitFastPolicy extends ContBothPolicy
```

Quit-fast execution policy for `both`/`all` operations.

Terminates as soon as the first failure occurs. Provides fastest feedback but other operations may continue running.

---

### ContEitherPolicy

```dart
sealed class ContEitherPolicy<A>
```

Execution policy for `either` and `any` operations.

Defines how multiple continuations should be executed and how their results should be combined when racing for the first success. Different policies provide different trade-offs between execution order, success handling, and result combination.

**Type Parameters:**
- `A`: The value type that the continuations produce

**Available Policies:**
- [EitherSequencePolicy](#eithersequencepolicy): Executes operations sequentially until one succeeds
- [EitherMergeWhenAllPolicy](#eithermergewhenallpolicy): Waits for all operations and merges multiple successes
- [EitherQuitFastPolicy](#eitherquitfastpolicy): Terminates immediately on the first success

**Static Factory Methods:**

```dart
static ContEitherPolicy<A> sequence<A>()
```
Creates a sequential execution policy. Operations are executed one after another in order. Execution continues until one succeeds or all fail.

When used with `either` or `any`:
- Continuations execute sequentially in the order provided
- If a continuation succeeds, returns immediately with that value
- If a continuation fails, tries the next one
- If all continuations fail, all errors are collected and concatenated

Use this when:
- You want to try fallback options one at a time
- Order of preference matters (try primary first, then fallback)
- You want to minimize resource usage by stopping at first success

**Example:**
```dart
final result = Cont.any(
  [fetchFromCache, fetchFromPrimaryDb, fetchFromBackupDb],
  policy: ContEitherPolicy.sequence(),
);
// Tries cache first, then primary DB, then backup DB
// Returns first successful result
```

---

```dart
static ContEitherPolicy<A> mergeWhenAll<A>(A Function(A a1, A a2) combine)
```
Creates a merge-when-all policy with a custom combiner. All operations are executed in parallel. If multiple operations succeed, their results are combined using the provided `combine` function. The function receives the accumulated value and the new value, returning the combined result.

When used with `either` or `any`:
- All continuations start executing in parallel
- Waits for all continuations to complete
- If multiple continuations succeed, combines their values using the `combine` function
- The combine function is called sequentially: `combine(combine(a1, a2), a3)` for three values
- If all continuations fail, all errors are collected and concatenated

Use this when:
- You want to execute all operations and merge their results
- Multiple successful outcomes should be combined (e.g., merging data from multiple sources)
- You need the aggregated result from all successful attempts

- **Parameters:**
  - `combine`: Function to merge two successful values. Called with the accumulated result and the next value.

**Example:**
```dart
final result = Cont.any(
  [fetchUserFromDb1, fetchUserFromDb2, fetchUserFromDb3],
  policy: ContEitherPolicy.mergeWhenAll((user1, user2) {
    // Merge user data, preferring non-null fields
    return User(
      name: user1.name ?? user2.name,
      email: user1.email ?? user2.email,
    );
  }),
);
// Fetches from all DBs and merges the results
```

---

```dart
static ContEitherPolicy<A> quitFast<A>()
```
Creates a quit-fast policy. Terminates immediately on the first success. Provides the fastest feedback but may leave other operations running.

When used with `either` or `any`:
- All continuations start executing in parallel
- Returns immediately when the first continuation succeeds
- Other operations may continue running in the background
- If all fail before any success, collects all errors

Use this when:
- You want the fastest possible success feedback
- Any single success is sufficient
- You don't need to wait for or combine multiple successful results

**Example:**
```dart
final result = Cont.either(
  fetchFromCdn,
  fetchFromOrigin,
  policy: ContEitherPolicy.quitFast(),
);
// Tries both sources in parallel
// Returns immediately when either succeeds
```

**Policy Type Details:**

#### EitherSequencePolicy

```dart
final class EitherSequencePolicy<A> extends ContEitherPolicy<A>
```

Sequential execution policy for `either`/`any` operations.

Executes continuations one after another in order. Continues until the first success or all operations fail.

#### EitherMergeWhenAllPolicy

```dart
final class EitherMergeWhenAllPolicy<A> extends ContEitherPolicy<A>
```

Merge-when-all execution policy for `either`/`any` operations.

Executes all continuations in parallel and waits for all to complete. Combines multiple successful results using the provided combine function.

**Fields:**
- `combine: A Function(A a1, A a2)` - Function to combine two successful values

#### EitherQuitFastPolicy

```dart
final class EitherQuitFastPolicy<A> extends ContEitherPolicy<A>
```

Quit-fast execution policy for `either`/`any` operations.

Terminates as soon as the first success occurs. Provides fastest feedback but other operations may continue running.

---

## Static Combinators

### Cont.both

```dart
static Cont<E, A3> both<E, A1, A2, A3>(
  Cont<E, A1> left,
  Cont<E, A2> right,
  A3 Function(A1 a, A2 a2) combine, {
  required ContBothPolicy policy,
})
```

Runs two continuations and combines their results according to the specified policy.

Executes both continuations. Both must succeed for the result to be successful; if either fails, the entire operation fails. When both succeed, their values are combined using `combine`.

The execution behavior depends on the provided `policy`:

- **BothSequencePolicy**: Runs `left` then `right` sequentially
- **BothMergeWhenAllPolicy**: Runs both in parallel, waits for both to complete, and merges errors if both fail
- **BothQuitFastPolicy**: Runs both in parallel, terminates immediately if either fails

- **Parameters:**
  - `left`: First continuation to execute
  - `right`: Second continuation to execute
  - `combine`: Function to combine both successful values
  - `policy`: Execution policy determining how continuations are run and errors are handled

**Example:**
```dart
// Sequential execution
final result = Cont.both(
  fetchUser(userId),
  fetchPosts(userId),
  (user, posts) => UserWithPosts(user, posts),
  policy: ContBothPolicy.sequence(),
);

// Parallel execution with quit-fast on failure
final result = Cont.both(
  validateCredentials,
  checkPermissions,
  (creds, perms) => AuthenticatedSession(creds, perms),
  policy: ContBothPolicy.quitFast(),
);
```

---

### Cont.all

```dart
static Cont<E, List<A>> all<E, A>(
  List<Cont<E, A>> list, {
  required ContBothPolicy policy,
})
```

Runs multiple continuations and collects all results according to the specified policy.

Executes all continuations in `list` and collects their values into a list. The execution behavior depends on the provided `policy`:

- **BothSequencePolicy**: Runs continuations one by one in order, stops at first failure
- **BothMergeWhenAllPolicy**: Runs all in parallel, waits for all to complete, and merges errors if any fail
- **BothQuitFastPolicy**: Runs all in parallel, terminates immediately on first failure

- **Parameters:**
  - `list`: List of continuations to execute
  - `policy`: Execution policy determining how continuations are run and errors are handled

**Example:**
```dart
// Run all validations and collect errors
final validations = Cont.all(
  [
    validateEmail(email),
    validatePassword(password),
    validateAge(age),
  ],
  policy: ContBothPolicy.mergeWhenAll(),
);

// Sequential execution
final results = Cont.all(
  [step1, step2, step3],
  policy: ContBothPolicy.sequence(),
);
```

---

### Cont.either

```dart
static Cont<E, A> either<E, A>(
  Cont<E, A> left,
  Cont<E, A> right, {
  required ContEitherPolicy<A> policy,
})
```

Races two continuations, returning the first successful value.

Executes both continuations and returns the result from whichever succeeds first. If both fail, concatenates their errors. The execution behavior depends on the provided `policy`:

- **EitherSequencePolicy**: Tries `left` first, then `right` if `left` fails
- **EitherMergeWhenAllPolicy**: Runs both in parallel, returns first success or merges multiple successes using the policy's combine function if both succeed
- **EitherQuitFastPolicy**: Runs both in parallel, returns immediately on first success

- **Parameters:**
  - `left`: First continuation to try
  - `right`: Second continuation to try
  - `policy`: Execution policy determining how continuations are run and how multiple successes are combined

**Example:**
```dart
// Try primary, then fallback
final data = Cont.either(
  fetchFromPrimary,
  fetchFromBackup,
  policy: ContEitherPolicy.sequence(),
);

// Race two sources
final data = Cont.either(
  fetchFromCdn,
  fetchFromOrigin,
  policy: ContEitherPolicy.quitFast(),
);
```

---

### Cont.any

```dart
static Cont<E, A> any<E, A>(
  List<Cont<E, A>> list, {
  required ContEitherPolicy<A> policy,
})
```

Races multiple continuations, returning the first successful value.

Executes all continuations in `list` and returns the first one that succeeds. If all fail, collects all errors. The execution behavior depends on the provided `policy`:

- **EitherSequencePolicy**: Tries continuations one by one in order until one succeeds
- **EitherMergeWhenAllPolicy**: Runs all in parallel, returns first success or merges multiple successes using the policy's combine function
- **EitherQuitFastPolicy**: Runs all in parallel, returns immediately on first success

- **Parameters:**
  - `list`: List of continuations to race
  - `policy`: Execution policy determining how continuations are run and how multiple successes are combined

**Example:**
```dart
// Try multiple sources in order
final data = Cont.any(
  [
    fetchFromCache,
    fetchFromPrimaryDb,
    fetchFromBackupDb,
  ],
  policy: ContEitherPolicy.sequence(),
);

// Race all sources
final data = Cont.any(
  [source1, source2, source3],
  policy: ContEitherPolicy.quitFast(),
);

// Merge results from all sources
final merged = Cont.any(
  [db1, db2, db3],
  policy: ContEitherPolicy.mergeWhenAll((a, b) => a + b),
);
```

---

## Instance Methods

### and

```dart
Cont<E, A3> and<A2, A3>(
  Cont<E, A2> right,
  A3 Function(A a, A2 a2) combine, {
  required ContBothPolicy policy,
})
```

Instance method for combining this continuation with another.

Convenient instance method wrapper for `Cont.both`. Executes this continuation and `right` according to the specified `policy`, then combines their values.

- **Parameters:**
  - `right`: The other continuation to combine with
  - `combine`: Function to combine both successful values
  - `policy`: Execution policy determining how continuations are run and errors are handled

**Example:**
```dart
final result = fetchUser(userId).and(
  fetchPosts(userId),
  (user, posts) => UserWithPosts(user, posts),
  policy: ContBothPolicy.quitFast(),
);
```

---

### or

```dart
Cont<E, A> or(
  Cont<E, A> right, {
  required ContEitherPolicy<A> policy,
})
```

Instance method for racing this continuation with another.

Convenient instance method wrapper for `Cont.either`. Races this continuation against `right`, returning the first successful value.

- **Parameters:**
  - `right`: The other continuation to race with
  - `policy`: Execution policy determining how continuations are run and how multiple successes are combined

**Example:**
```dart
final data = fetchFromPrimary.or(
  fetchFromBackup,
  policy: ContEitherPolicy.sequence(),
);
```
