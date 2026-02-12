[Home](../../README.md) > [Documentation](../README.md) > [API Reference](README.md)

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
- [Termination](#termination)
  - [abort](#abort)
  - [abort0](#abort0)
  - [abortWithEnv](#abortwithenv)
  - [abortWithEnv0](#abortwithenv0)
  - [abortWith](#abortwith)
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
  - [forever](#forever)

---

## Basic Transformations

### thenMap

```dart
Cont<E, A2> thenMap<A2>(A2 Function(A value) f)
```

Transforms the value inside a `Cont` using a pure function.

Applies a function to the successful value of the continuation without affecting the termination case.

- **Parameters:**
  - `f`: Transformation function to apply to the value

**Example:**
```dart
final cont = Cont.of(42).thenMap((n) => n * 2);
cont.run((), onThen: print); // prints: 84
```

---

### thenMap0

```dart
Cont<E, A2> thenMap0<A2>(A2 Function() f)
```

Transforms the value inside a `Cont` using a zero-argument function.

Similar to `thenMap` but ignores the current value and computes a new one.

- **Parameters:**
  - `f`: Zero-argument transformation function

**Example:**
```dart
final cont = Cont.of(42).thenMap0(() => 'done');
cont.run((), onThen: print); // prints: done
```

---

### thenMapWithEnv

```dart
Cont<E, A2> thenMapWithEnv<A2>(A2 Function(E env, A value) f)
```

Transforms the value with access to both the value and environment.

Similar to `thenMap`, but the transformation function receives both the current value and the environment. This is useful when the transformation needs access to configuration or context information.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a new value

**Example:**
```dart
final cont = Cont.of(42)
  .thenMapWithEnv((env, n) => n * env.multiplier);
```

---

### thenMapWithEnv0

```dart
Cont<E, A2> thenMapWithEnv0<A2>(A2 Function(E env) f)
```

Transforms the value with access to the environment only.

Similar to `thenMapWithEnv`, but the transformation function only receives the environment and ignores the current value.

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
Cont<E, A2> thenMapTo<A2>(A2 value)
```

Replaces the value inside a `Cont` with a constant.

Discards the current value and replaces it with a fixed value.

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
Cont<E, A2> thenDo<A2>(Cont<E, A2> Function(A value) f)
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
Cont<E, A2> thenDo0<A2>(Cont<E, A2> Function() f)
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
Cont<E, A2> thenDoWithEnv<A2>(Cont<E, A2> Function(E env, A a) f)
```

Chains a continuation-returning function that has access to both the environment and the value.

Similar to `thenDo`, but the function receives both the environment and the value. This is useful when the next computation needs access to configuration or context from the environment.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenDoWithEnv((env, user) {
    // Can access both env and user
    return logActivity(env.logger, user);
  });
```

---

### thenDoWithEnv0

```dart
Cont<E, A2> thenDoWithEnv0<A2>(Cont<E, A2> Function(E env) f)
```

Chains a continuation-returning function with access to the environment only.

Similar to `thenDoWithEnv`, but the function only receives the environment and ignores the current value. This is useful when the next computation needs access to configuration or context but doesn't depend on the previous value.

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
Cont<E, A> thenTap<A2>(Cont<E, A2> Function(A value) f)
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
Cont<E, A> thenTap0<A2>(Cont<E, A2> Function() f)
```

Chains a zero-argument side-effect continuation.

Similar to `thenTap` but with a zero-argument function.

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
Cont<E, A> thenTapWithEnv<A2>(Cont<E, A2> Function(E env, A a) f)
```

Chains a side-effect continuation with access to both the environment and the value.

Similar to `thenTap`, but the side-effect function receives both the environment and the value. After executing the side-effect, returns the original value. This is useful for logging, monitoring, or other side-effects that need access to both the environment and configuration context.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a side-effect continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenTapWithEnv((env, user) => env.logger.info('Fetched user: ${user.id}'));
```

---

### thenTapWithEnv0

```dart
Cont<E, A> thenTapWithEnv0<A2>(Cont<E, A2> Function(E env) f)
```

Chains a side-effect continuation with access to the environment only.

Similar to `thenTapWithEnv`, but the side-effect function only receives the environment and ignores the current value. After executing the side-effect, returns the original value.

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
Cont<E, A3> thenZip<A2, A3>(Cont<E, A2> Function(A value) f, A3 Function(A a1, A2 a2) combine)
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
Cont<E, A3> thenZip0<A2, A3>(Cont<E, A2> Function() f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines with a zero-argument function.

Similar to `thenZip` but the second continuation doesn't depend on the first value.

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
Cont<E, A3> thenZipWithEnv<A2, A3>(Cont<E, A2> Function(E env, A value) f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines two continuations with access to the environment.

Similar to `thenZip`, but the function producing the second continuation receives both the environment and the value. This is useful when the second computation needs access to configuration or context.

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
Cont<E, A3> thenZipWithEnv0<A2, A3>(Cont<E, A2> Function(E env) f, A3 Function(A a1, A2 a2) combine)
```

Chains and combines with a continuation that has access to the environment only.

Similar to `thenZipWithEnv`, but the function producing the second continuation only receives the environment and ignores the current value.

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
Cont<E, A> thenFork<A2>(Cont<E, A2> Function(A a) f)
```

Executes a side-effect continuation in a fire-and-forget manner.

Unlike `thenTap`, this method does not wait for the side-effect to complete. The side-effect continuation is started immediately, and the original value is returned without delay. Any errors from the side-effect are silently ignored.

- **Parameters:**
  - `f`: Function that takes the current value and returns a side-effect continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenFork((user) => sendAnalytics(user.id))
  .thenDo((user) => processUser(user)); // Continues immediately
```

---

### thenFork0

```dart
Cont<E, A> thenFork0<A2>(Cont<E, A2> Function() f)
```

Executes a zero-argument side-effect continuation in a fire-and-forget manner.

Similar to `thenFork` but ignores the current value.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

**Example:**
```dart
final result = validateData()
  .thenFork0(() => backgroundCleanup());
```

---

### thenForkWithEnv

```dart
Cont<E, A> thenForkWithEnv<A2>(Cont<E, A2> Function(E env, A a) f)
```

Executes a side-effect continuation in a fire-and-forget manner with access to the environment.

Similar to `thenFork`, but the side-effect function receives both the environment and the value. The side-effect is started immediately without waiting, and any errors are silently ignored.

- **Parameters:**
  - `f`: Function that takes the environment and value, and returns a side-effect continuation

**Example:**
```dart
final result = fetchUser(userId)
  .thenForkWithEnv((env, user) => env.analytics.track(user));
```

---

### thenForkWithEnv0

```dart
Cont<E, A> thenForkWithEnv0<A2>(Cont<E, A2> Function(E env) f)
```

Executes a side-effect continuation in a fire-and-forget manner with access to the environment only.

Similar to `thenForkWithEnv`, but the side-effect function only receives the environment and ignores the current value.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

**Example:**
```dart
final result = processRequest()
  .thenForkWithEnv0((env) => env.cache.cleanup());
```

---

## Termination

### abort

```dart
Cont<E, A> abort(List<ContError> Function(A value) f)
```

Unconditionally terminates the continuation with computed errors.

Takes a successful value and converts it into a termination with errors. This is useful for implementing validation logic where certain values should cause termination, or for custom error handling flows.

- **Parameters:**
  - `f`: Function that computes the error list from the value

**Example:**
```dart
final cont = Cont.of(42)
  .abort((n) => [ContError.capture('Value too large: $n')]);
// Terminates with error

final validated = fetchUser()
  .abort((user) => user.age < 18
    ? [ContError.capture('User must be 18+')]
    : []);
```

---

### abort0

```dart
Cont<E, A> abort0(List<ContError> Function() f)
```

Unconditionally terminates with errors computed from a zero-argument function.

Similar to `abort` but the error computation doesn't depend on the value.

- **Parameters:**
  - `f`: Zero-argument function that computes the error list

**Example:**
```dart
final cont = Cont.of(42)
  .abort0(() => [ContError.capture('Operation cancelled')]);
```

---

### abortWithEnv

```dart
Cont<E, A> abortWithEnv(List<ContError> Function(E env, A value) f)
```

Unconditionally terminates with errors computed from both value and environment.

Similar to `abort`, but the error computation function receives both the current value and the environment. This is useful when error creation needs access to configuration or context information.

- **Parameters:**
  - `f`: Function that takes the environment and value, and computes the error list

**Example:**
```dart
final validated = fetchValue()
  .abortWithEnv((env, value) {
    return value > env.maxAllowed
      ? [ContError.capture('Exceeds limit: ${env.maxAllowed}')]
      : [];
  });
```

---

### abortWithEnv0

```dart
Cont<E, A> abortWithEnv0(List<ContError> Function(E env) f)
```

Unconditionally terminates with errors computed from the environment only.

Similar to `abortWithEnv`, but the error computation function only receives the environment and ignores the current value.

- **Parameters:**
  - `f`: Function that takes the environment and computes the error list

**Example:**
```dart
final cont = processData()
  .abortWithEnv0((env) {
    return env.isMaintenanceMode
      ? [ContError.capture('System in maintenance')]
      : [];
  });
```

---

### abortWith

```dart
Cont<E, A> abortWith(List<ContError> errors)
```

Unconditionally terminates with a fixed list of errors.

Replaces any successful value with a termination containing the provided errors. This is the simplest form of forced termination.

- **Parameters:**
  - `errors`: The error list to terminate with

**Example:**
```dart
final cont = Cont.of(42)
  .abortWith([ContError.capture('Forced termination')]);
```

---

## Conditionals

### thenIf

```dart
Cont<E, A> thenIf(bool Function(A value) predicate)
```

Conditionally succeeds only when the predicate is satisfied.

Filters the continuation based on the predicate. If the predicate returns `true`, the continuation succeeds with the value. If the predicate returns `false`, the continuation terminates without errors.

This is useful for conditional execution where you want to treat a predicate failure as termination rather than an error.

- **Parameters:**
  - `predicate`: Function that tests the value

**Example:**
```dart
final cont = Cont.of(42).thenIf((n) => n > 0);
// Succeeds with 42

final cont2 = Cont.of(-5).thenIf((n) => n > 0);
// Terminates

// Real-world usage
final result = fetchUser(userId)
  .thenIf((user) => user.isActive)
  .thenDo((user) => processActiveUser(user));
```

---

### thenIf0

```dart
Cont<E, A> thenIf0(bool Function() predicate)
```

Conditionally succeeds based on a zero-argument predicate.

Similar to `thenIf` but the predicate doesn't examine the value.

- **Parameters:**
  - `predicate`: Zero-argument function that determines success or termination

**Example:**
```dart
var shouldProceed = true;
final cont = Cont.of(42)
  .thenIf0(() => shouldProceed);
```

---

### thenIfWithEnv

```dart
Cont<E, A> thenIfWithEnv(bool Function(E env, A value) predicate)
```

Conditionally succeeds with access to both value and environment.

Similar to `thenIf`, but the predicate function receives both the current value and the environment. This is useful when conditional logic needs access to configuration or context information.

- **Parameters:**
  - `predicate`: Function that takes the environment and value, and determines success or termination

**Example:**
```dart
final cont = fetchUser(userId)
  .thenIfWithEnv((env, user) => user.level >= env.minRequiredLevel);
```

---

### thenIfWithEnv0

```dart
Cont<E, A> thenIfWithEnv0(bool Function(E env) predicate)
```

Conditionally succeeds with access to the environment only.

Similar to `thenIfWithEnv`, but the predicate only receives the environment and ignores the current value.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines success or termination

**Example:**
```dart
final cont = processData()
  .thenIfWithEnv0((env) => env.featureEnabled);
```

---

## Loops

### thenWhile

```dart
Cont<E, A> thenWhile(bool Function(A value) predicate)
```

Repeatedly executes the continuation as long as the predicate returns `true`, stopping when it returns `false`.

Runs the continuation in a loop, testing each result with the predicate. The loop continues as long as the predicate returns `true`, and stops successfully when the predicate returns `false`.

The loop is stack-safe and handles asynchronous continuations correctly. If the continuation terminates or if the predicate throws an exception, the loop stops and propagates the errors.

This is useful for retry logic, polling, or repeating an operation while a condition holds.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to continue looping, or `false` to stop and succeed with the value

**Example:**
```dart
// Poll an API while data is not ready
final result = fetchData().thenWhile((response) => !response.isReady);

// Retry while value is below threshold
final value = computation().thenWhile((n) => n < 100);
```

---

### thenWhile0

```dart
Cont<E, A> thenWhile0(bool Function() predicate)
```

Repeatedly executes based on a zero-argument predicate.

Similar to `thenWhile` but the predicate doesn't examine the value.

- **Parameters:**
  - `predicate`: Zero-argument function that determines whether to continue looping

**Example:**
```dart
var shouldContinue = true;
final result = operation()
  .thenWhile0(() => shouldContinue);
```

---

### thenWhileWithEnv

```dart
Cont<E, A> thenWhileWithEnv(bool Function(E env, A value) predicate)
```

Repeatedly executes with access to both value and environment.

Similar to `thenWhile`, but the predicate function receives both the current value and the environment. This is useful when loop logic needs access to configuration or context information.

- **Parameters:**
  - `predicate`: Function that takes the environment and value, and determines whether to continue looping

**Example:**
```dart
final result = fetchData()
  .thenWhileWithEnv((env, data) => data.size < env.maxSize);
```

---

### thenWhileWithEnv0

```dart
Cont<E, A> thenWhileWithEnv0(bool Function(E env) predicate)
```

Repeatedly executes with access to the environment only.

Similar to `thenWhileWithEnv`, but the predicate only receives the environment and ignores the current value.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines whether to continue looping

**Example:**
```dart
final result = processData()
  .thenWhileWithEnv0((env) => !env.shutdownRequested);
```

---

### thenUntil

```dart
Cont<E, A> thenUntil(bool Function(A value) predicate)
```

Repeatedly executes the continuation until the predicate returns `true`.

Runs the continuation in a loop, testing each result with the predicate. The loop continues while the predicate returns `false`, and stops successfully when the predicate returns `true`.

This is the inverse of `thenWhile` - implemented as `thenWhile((a) => !predicate(a))`. Use this when you want to retry until a condition is met.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to stop the loop and succeed, or `false` to continue looping

**Example:**
```dart
// Retry until a condition is met
final result = fetchStatus().thenUntil((status) => status == 'complete');

// Poll until a threshold is reached
final value = checkProgress().thenUntil((progress) => progress >= 100);
```

---

### thenUntil0

```dart
Cont<E, A> thenUntil0(bool Function() predicate)
```

Repeatedly executes until a zero-argument predicate returns `true`.

Similar to `thenUntil` but the predicate doesn't examine the value.

- **Parameters:**
  - `predicate`: Zero-argument function that determines when to stop looping

**Example:**
```dart
var targetReached = false;
final result = operation()
  .thenUntil0(() => targetReached);
```

---

### thenUntilWithEnv

```dart
Cont<E, A> thenUntilWithEnv(bool Function(E env, A value) predicate)
```

Repeatedly executes with access to both value and environment.

Similar to `thenUntil`, but the predicate function receives both the current value and the environment. This is useful when loop logic needs access to configuration or context information.

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
Cont<E, A> thenUntilWithEnv0(bool Function(E env) predicate)
```

Repeatedly executes with access to the environment only.

Similar to `thenUntilWithEnv`, but the predicate only receives the environment and ignores the current value.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines when to stop

**Example:**
```dart
final result = pollService()
  .thenUntilWithEnv0((env) => env.serviceReady);
```

---

### forever

```dart
Cont<E, Never> forever()
```

Repeatedly executes the continuation indefinitely.

Runs the continuation in an infinite loop that never stops on its own. The loop only terminates if the underlying continuation terminates with an error.

The return type `Cont<E, Never>` indicates that this continuation never produces a value - it either runs forever or terminates with errors.

This is useful for:
- Daemon-like processes that run continuously
- Server loops that handle requests indefinitely
- Event loops that continuously process events
- Background tasks that should never stop

**Example:**
```dart
// A server that handles requests forever
final server = acceptConnection()
    .thenDo((conn) => handleConnection(conn))
    .forever();

// Run with only a termination handler (using trap extension)
final token = server.trap(env, onElse: (errors) => print('Server stopped: $errors'));

// Can cancel the server when needed
// token.cancel();

// Event loop
final eventLoop = pollEvents()
    .thenDo((event) => handleEvent(event))
    .forever();
```
