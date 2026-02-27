[Home](../../README.md) > API Reference > Then Channel Operations

# Then Channel Operations

Success path operations for transforming, chaining, and controlling flow.

---

## Table of Contents

- [Basic Transformations](#basic-transformations)
  - [thenMap](#thenmap)
  - [thenMap0](#thenmap0)
  - [thenMapWithEnv](#thenmapwithenv)
  - [thenMapWithEnv0](#thenmapwithenv0)
  - [thenMapTo](#thenmapto)
- [Chaining](#chaining)
  - [thenDo](#thendo)
  - [thenDo0](#thendo0)
  - [thenDoWithEnv](#thendowithenv)
  - [thenDoWithEnv0](#thendowithenv0)
- [Side Effects](#side-effects)
  - [thenTap](#thentap)
  - [thenTap0](#thentap0)
  - [thenTapWithEnv](#thentapwithenv)
  - [thenTapWithEnv0](#thentapwithenv0)
- [Combining Values](#combining-values)
  - [thenZip](#thenzip)
  - [thenZip0](#thenzip0)
  - [thenZipWithEnv](#thenzipwithenv)
  - [thenZipWithEnv0](#thenzipwithenv0)
- [Fire and Forget](#fire-and-forget)
  - [thenFork](#thenfork)
  - [thenFork0](#thenfork0)
  - [thenForkWithEnv](#thenforkwithenv)
  - [thenForkWithEnv0](#thenforkwithenv0)
- [Demotion](#demotion)
  - [demote](#demote)
  - [demote0](#demote0)
  - [demoteWithEnv](#demotewithenv)
  - [demoteWithEnv0](#demotewithenv0)
  - [demoteWith](#demotewith)
- [Conditionals](#conditionals)
  - [thenIf](#thenif)
  - [thenIf0](#thenif0)
  - [thenIfWithEnv](#thenifwithenv)
  - [thenIfWithEnv0](#thenifwithenv0)
- [Loops](#loops)
  - [thenWhile](#thenwhile)
  - [thenWhile0](#thenwhile0)
  - [thenWhileWithEnv](#thenwhilewithenv)
  - [thenWhileWithEnv0](#thenwhilewithenv0)
  - [thenUntil](#thenuntil)
  - [thenUntil0](#thenuntil0)
  - [thenUntilWithEnv](#thenuntilwithenv)
  - [thenUntilWithEnv0](#thenuntilwithenv0)
  - [thenForever](#thenforever)

---

## Basic Transformations

### thenMap

```dart
Cont<E, F, A2> thenMap<A2>(A2 Function(A value) f)
```

Transforms the value inside a `Cont` using a pure function.

Applies a function to the successful value of the continuation without affecting the error or crash channels.

- **Parameters:**
  - `f`: Transformation function to apply to the value

**Example:**
```dart
final cont = Cont.of<(), Never, int>(42).thenMap((n) => n * 2);
cont.run((), onThen: print); // prints: 84
```

---

### thenMap0

```dart
Cont<E, F, A2> thenMap0<A2>(A2 Function() f)
```

Transforms the value using a zero-argument function.

Similar to `thenMap` but ignores the current value and computes a new one.

- **Parameters:**
  - `f`: Zero-argument transformation function

**Example:**
```dart
final cont = Cont.of<(), Never, int>(42).thenMap0(() => 'done');
cont.run((), onThen: print); // prints: done
```

---

### thenMapWithEnv

```dart
Cont<E, F, A2> thenMapWithEnv<A2>(A2 Function(E env, A value) f)
```

Transforms the value with access to both the value and environment.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a new value

**Example:**
```dart
final cont = Cont.of<Config, Never, int>(42)
  .thenMapWithEnv((env, n) => n * env.multiplier);
```

---

### thenMapWithEnv0

```dart
Cont<E, F, A2> thenMapWithEnv0<A2>(A2 Function(E env) f)
```

Transforms the value with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a new value

**Example:**
```dart
final cont = validateInput()
  .thenMapWithEnv0((env) => env.config.defaultValue);
```

---

### thenMapTo

```dart
Cont<E, F, A2> thenMapTo<A2>(A2 value)
```

Replaces the value inside a `Cont` with a constant.

- **Parameters:**
  - `value`: The constant value to replace with

**Example:**
```dart
final cont = fetchUser().thenMapTo('User fetched');
cont.run(env, onThen: print); // prints: User fetched
```

---

## Chaining

### thenDo

```dart
Cont<E, F, A2> thenDo<A2>(Cont<E, F, A2> Function(A value) f)
```

Chains a `Cont`-returning function to create dependent computations.

Monadic bind operation. Sequences continuations where the second depends on the result of the first.

- **Parameters:**
  - `f`: Function that takes a value and returns a continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenDo((user) => fetchPosts(user.id))
  .thenDo((posts) => enrichPosts(posts));
```

---

### thenDo0

```dart
Cont<E, F, A2> thenDo0<A2>(Cont<E, F, A2> Function() f)
```

Chains a `Cont`-returning zero-argument function.

Similar to `thenDo` but ignores the current value.

- **Parameters:**
  - `f`: Zero-argument function that returns a continuation

**Example:**
```dart
final result = validateUser()
  .thenDo0(() => sendWelcomeEmail());
```

---

### thenDoWithEnv

```dart
Cont<E, F, A2> thenDoWithEnv<A2>(Cont<E, F, A2> Function(E env, A a) f)
```

Chains a continuation-returning function with access to both environment and value.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenDoWithEnv((env, user) => logActivity(env.logger, user));
```

---

### thenDoWithEnv0

```dart
Cont<E, F, A2> thenDoWithEnv0<A2>(Cont<E, F, A2> Function(E env) f)
```

Chains a continuation-returning function with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a continuation

**Example:**
```dart
final result = validateInput()
  .thenDoWithEnv0((env) => fetchFromApi(env.apiUrl));
```

---

## Side Effects

### thenTap

```dart
Cont<E, F, A> thenTap<A2>(Cont<E, F, A2> Function(A value) f)
```

Chains a side-effect continuation while preserving the original value.

Executes a continuation for its side effects, then returns the original value.

- **Parameters:**
  - `f`: Side-effect function that returns a continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenTap((user) => logAccess(user.id))
  .thenDo((user) => processUser(user)); // Still has the user
```

---

### thenTap0

```dart
Cont<E, F, A> thenTap0<A2>(Cont<E, F, A2> Function() f)
```

Chains a zero-argument side-effect continuation.

- **Parameters:**
  - `f`: Zero-argument side-effect function

**Example:**
```dart
final result = fetchData()
  .thenTap0(() => incrementCounter());
```

---

### thenTapWithEnv

```dart
Cont<E, F, A> thenTapWithEnv<A2>(Cont<E, F, A2> Function(E env, A a) f)
```

Chains a side-effect continuation with access to both environment and value.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a side-effect continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenTapWithEnv((env, user) => env.logger.info('Fetched: ${user.id}'));
```

---

### thenTapWithEnv0

```dart
Cont<E, F, A> thenTapWithEnv0<A2>(Cont<E, F, A2> Function(E env) f)
```

Chains a side-effect continuation with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

**Example:**
```dart
final result = validateInput()
  .thenTapWithEnv0((env) => env.metrics.increment('validations'));
```

---

## Combining Values

### thenZip

```dart
Cont<E, F, A3> thenZip<A2, A3>(
  Cont<E, F, A2> Function(A value) f,
  A3 Function(A a1, A2 a2) combine,
)
```

Chains and combines two continuation values.

Sequences two continuations and combines their results using the provided function.

- **Parameters:**
  - `f`: Function to produce the second continuation from the first value
  - `combine`: Function to combine both values into a result

**Example:**
```dart
final result = fetchUser(userId)
  .thenZip(
    (user) => fetchSettings(user.id),
    (user, settings) => UserProfile(user, settings),
  );
```

---

### thenZip0

```dart
Cont<E, F, A3> thenZip0<A2, A3>(
  Cont<E, F, A2> Function() f,
  A3 Function(A a1, A2 a2) combine,
)
```

Chains and combines with a zero-argument function.

- **Parameters:**
  - `f`: Zero-argument function to produce the second continuation
  - `combine`: Function to combine both values into a result

**Example:**
```dart
final result = fetchUser(userId)
  .thenZip0(
    () => fetchGlobalConfig(),
    (user, config) => enrichUser(user, config),
  );
```

---

### thenZipWithEnv

```dart
Cont<E, F, A3> thenZipWithEnv<A2, A3>(
  Cont<E, F, A2> Function(E env, A value) f,
  A3 Function(A a1, A2 a2) combine,
)
```

Chains and combines two continuations with access to the environment.

- **Parameters:**
  - `f`: Function that takes the environment and value, and produces the second continuation
  - `combine`: Function to combine both values into a result

**Example:**
```dart
final result = fetchUser(userId)
  .thenZipWithEnv(
    (env, user) => fetchFromApi(env.apiUrl, user.id),
    (user, data) => UserWithData(user, data),
  );
```

---

### thenZipWithEnv0

```dart
Cont<E, F, A3> thenZipWithEnv0<A2, A3>(
  Cont<E, F, A2> Function(E env) f,
  A3 Function(A a1, A2 a2) combine,
)
```

Chains and combines with a continuation that has access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and produces the second continuation
  - `combine`: Function to combine both values into a result

**Example:**
```dart
final result = validateInput()
  .thenZipWithEnv0(
    (env) => env.configService.get(),
    (input, config) => processWithConfig(input, config),
  );
```

---

## Fire and Forget

### thenFork

```dart
Cont<E, F, A> thenFork<F2, A2>(
  Cont<E, F2, A2> Function(A a) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a side-effect continuation in a fire-and-forget manner.

Unlike `thenTap`, this method does not wait for the side-effect to complete. The side-effect continuation is started immediately, and the original value is returned without delay. The forked continuation may have different error and value types.

Outcomes from the forked continuation are dispatched to optional callbacks:
- `onPanic`: Called when the side-effect triggers a panic. Defaults to rethrowing.
- `onCrash`: Called when the side-effect crashes. Defaults to ignoring.
- `onElse`: Called when the side-effect terminates with an error. Defaults to ignoring.
- `onThen`: Called when the side-effect succeeds. Defaults to ignoring.

- **Parameters:**
  - `f`: Function that takes the current value and returns a side-effect continuation
  - `onPanic`: *(optional)* Handler for panics in the side-effect
  - `onCrash`: *(optional)* Handler for crashes in the side-effect
  - `onElse`: *(optional)* Handler for errors in the side-effect
  - `onThen`: *(optional)* Handler for success in the side-effect

**Example:**
```dart
final result = fetchUser(userId)
  .thenFork((user) => sendAnalytics(user.id))
  .thenDo((user) => processUser(user)); // Continues immediately

// With observation callbacks:
final result2 = fetchUser(userId)
  .thenFork(
    (user) => sendAnalytics(user.id),
    onElse: (error) => print('Analytics failed: $error'),
  );
```

---

### thenFork0

```dart
Cont<E, F, A> thenFork0<F2, A2>(
  Cont<E, F2, A2> Function() f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a zero-argument side-effect continuation in a fire-and-forget manner.

Accepts the same optional observation callbacks as `thenFork`.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation
  - `onPanic`, `onCrash`, `onElse`, `onThen`: *(optional)* Outcome observation callbacks (see `thenFork`)

**Example:**
```dart
final result = validateData()
  .thenFork0(() => backgroundCleanup());
```

---

### thenForkWithEnv

```dart
Cont<E, F, A> thenForkWithEnv<F2, A2>(
  Cont<E, F2, A2> Function(E env, A a) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a side-effect continuation in a fire-and-forget manner with access to the environment.

Accepts the same optional observation callbacks as `thenFork`.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a side-effect continuation
  - `onPanic`, `onCrash`, `onElse`, `onThen`: *(optional)* Outcome observation callbacks (see `thenFork`)

**Example:**
```dart
final result = fetchUser(userId)
  .thenForkWithEnv((env, user) => env.analytics.track(user));
```

---

### thenForkWithEnv0

```dart
Cont<E, F, A> thenForkWithEnv0<F2, A2>(
  Cont<E, F2, A2> Function(E env) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a side-effect continuation in a fire-and-forget manner with access to the environment only.

Accepts the same optional observation callbacks as `thenFork`.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation
  - `onPanic`, `onCrash`, `onElse`, `onThen`: *(optional)* Outcome observation callbacks (see `thenFork`)

**Example:**
```dart
final result = processRequest()
  .thenForkWithEnv0((env) => env.cache.cleanup());
```

---

## Demotion

### demote

```dart
Cont<E, F, A> demote(F Function(A value) f)
```

Unconditionally demotes a successful value to a typed error.

Takes a successful value and converts it into a termination with a typed error. This is useful for implementing validation logic where certain values should cause termination.

- **Parameters:**
  - `f`: Function that computes the error from the value

**Example:**
```dart
final cont = Cont.of<(), String, int>(42)
  .demote((n) => 'Value too large: $n');
// Terminates with error 'Value too large: 42'
```

---

### demote0

```dart
Cont<E, F, A> demote0(F Function() f)
```

Unconditionally demotes with an error computed from a zero-argument function.

- **Parameters:**
  - `f`: Zero-argument function that computes the error

**Example:**
```dart
final cont = Cont.of<(), String, int>(42)
  .demote0(() => 'Operation cancelled');
```

---

### demoteWithEnv

```dart
Cont<E, F, A> demoteWithEnv(F Function(E env, A value) f)
```

Unconditionally demotes with an error computed from both value and environment.

- **Parameters:**
  - `f`: Function that takes the environment and value, and computes the error

**Example:**
```dart
final validated = fetchValue()
  .demoteWithEnv((env, value) => 'Exceeds limit: ${env.maxAllowed}');
```

---

### demoteWithEnv0

```dart
Cont<E, F, A> demoteWithEnv0(F Function(E env) f)
```

Unconditionally demotes with an error computed from the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and computes the error

**Example:**
```dart
final cont = processData()
  .demoteWithEnv0((env) => 'Maintenance mode: ${env.reason}');
```

---

### demoteWith

```dart
Cont<E, F, A> demoteWith(F error)
```

Unconditionally demotes with a fixed error value.

Replaces any successful value with a termination containing the provided error.

- **Parameters:**
  - `error`: The error value to terminate with

**Example:**
```dart
final cont = Cont.of<(), String, int>(42)
  .demoteWith('Forced termination');
```

---

## Conditionals

### thenIf

```dart
Cont<E, F, A> thenIf(
  bool Function(A value) predicate, {
  required F fallback,
})
```

Conditionally succeeds only when the predicate is satisfied.

If the predicate returns `true`, the continuation succeeds with the value. If `false`, the continuation terminates with the `fallback` error.

- **Parameters:**
  - `predicate`: Function that tests the value
  - `fallback`: The error to use when the predicate returns `false`

**Example:**
```dart
final cont = Cont.of<(), String, int>(42)
  .thenIf((n) => n > 0, fallback: 'Value must be positive');
// Succeeds with 42

final cont2 = Cont.of<(), String, int>(-5)
  .thenIf((n) => n > 0, fallback: 'Value must be positive');
// Terminates with 'Value must be positive'
```

---

### thenIf0

```dart
Cont<E, F, A> thenIf0(
  bool Function() predicate, {
  required F fallback,
})
```

Conditionally succeeds based on a zero-argument predicate.

- **Parameters:**
  - `predicate`: Zero-argument function that determines success or termination
  - `fallback`: The error to use when the predicate returns `false`

**Example:**
```dart
var shouldProceed = true;
final cont = Cont.of<(), String, int>(42)
  .thenIf0(() => shouldProceed, fallback: 'Execution not allowed');
```

---

### thenIfWithEnv

```dart
Cont<E, F, A> thenIfWithEnv(
  bool Function(E env, A value) predicate, {
  required F fallback,
})
```

Conditionally succeeds with access to both value and environment.

- **Parameters:**
  - `predicate`: Function that takes the environment and value, and determines success or termination
  - `fallback`: The error to use when the predicate returns `false`

**Example:**
```dart
final cont = fetchUser(userId)
  .thenIfWithEnv(
    (env, user) => user.level >= env.minRequiredLevel,
    fallback: 'User level below minimum requirement',
  );
```

---

### thenIfWithEnv0

```dart
Cont<E, F, A> thenIfWithEnv0(
  bool Function(E env) predicate, {
  required F fallback,
})
```

Conditionally succeeds with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines success or termination
  - `fallback`: The error to use when the predicate returns `false`

**Example:**
```dart
final cont = processData()
  .thenIfWithEnv0(
    (env) => env.featureEnabled,
    fallback: 'Feature is disabled',
  );
```

---

## Loops

### thenWhile

```dart
Cont<E, F, A> thenWhile(bool Function(A value) predicate)
```

Repeatedly executes the continuation as long as the predicate returns `true`.

Runs the continuation in a loop. The loop continues while the predicate returns `true` and stops successfully when it returns `false`.

The loop is stack-safe. If the continuation terminates with an error or crashes, the loop stops and propagates the outcome.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to continue, `false` to stop

**Example:**
```dart
final result = fetchData().thenWhile((response) => !response.isReady);
```

---

### thenWhile0

```dart
Cont<E, F, A> thenWhile0(bool Function() predicate)
```

Repeatedly executes based on a zero-argument predicate.

- **Parameters:**
  - `predicate`: Zero-argument function that determines whether to continue looping

**Example:**
```dart
var shouldContinue = true;
final result = operation().thenWhile0(() => shouldContinue);
```

---

### thenWhileWithEnv

```dart
Cont<E, F, A> thenWhileWithEnv(bool Function(E env, A value) predicate)
```

Repeatedly executes with access to both value and environment.

- **Parameters:**
  - `predicate`: Function that takes the environment and value, and determines whether to continue

**Example:**
```dart
final result = fetchData()
  .thenWhileWithEnv((env, data) => data.size < env.maxSize);
```

---

### thenWhileWithEnv0

```dart
Cont<E, F, A> thenWhileWithEnv0(bool Function(E env) predicate)
```

Repeatedly executes with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines whether to continue

**Example:**
```dart
final result = processData()
  .thenWhileWithEnv0((env) => !env.shutdownRequested);
```

---

### thenUntil

```dart
Cont<E, F, A> thenUntil(bool Function(A value) predicate)
```

Repeatedly executes the continuation until the predicate returns `true`.

The inverse of `thenWhile`. The loop continues while the predicate returns `false` and stops when it returns `true`.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to stop, `false` to continue

**Example:**
```dart
final result = fetchStatus().thenUntil((status) => status == 'complete');
```

---

### thenUntil0

```dart
Cont<E, F, A> thenUntil0(bool Function() predicate)
```

Repeatedly executes until a zero-argument predicate returns `true`.

- **Parameters:**
  - `predicate`: Zero-argument function that determines when to stop

**Example:**
```dart
var targetReached = false;
final result = operation().thenUntil0(() => targetReached);
```

---

### thenUntilWithEnv

```dart
Cont<E, F, A> thenUntilWithEnv(bool Function(E env, A value) predicate)
```

Repeatedly executes with access to both value and environment.

- **Parameters:**
  - `predicate`: Function that takes the environment and value, and determines when to stop

**Example:**
```dart
final result = fetchData()
  .thenUntilWithEnv((env, data) => data.quality >= env.minQuality);
```

---

### thenUntilWithEnv0

```dart
Cont<E, F, A> thenUntilWithEnv0(bool Function(E env) predicate)
```

Repeatedly executes with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines when to stop

**Example:**
```dart
final result = pollService()
  .thenUntilWithEnv0((env) => env.serviceReady);
```

---

### thenForever

```dart
Cont<E, F, Never> thenForever()
```

Repeatedly executes the continuation indefinitely.

Runs the continuation in an infinite loop. The loop only terminates if the continuation terminates with an error or crashes.

The return type `Cont<E, F, Never>` indicates that this continuation never produces a value.

This is useful for daemon-like processes, server loops, and event loops.

**Example:**
```dart
final server = acceptConnection()
  .thenDo((conn) => handleConnection(conn))
  .thenForever();

final token = server.run(env, onElse: (error) => print('Server stopped: $error'));
token.cancel();
```
