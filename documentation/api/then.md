# Then Channel Operations

Success path operations for transforming, chaining, and controlling flow.

---

## Table of Contents

- [Basic Transformations](#basic-transformations)
  - [map](#map)
  - [map0](#map0)
  - [as](#as)
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
- [Conditionals](#conditionals)
  - [thenIf](#thenif)
- [Loops](#loops)
  - [asLongAs](#aslongas)
  - [until](#until)
  - [forever](#forever)

---

## Basic Transformations

### map

```dart
Cont<E, A2> map<A2>(A2 Function(A value) f)
```

Transforms the value inside a `Cont` using a pure function.

Applies a function to the successful value of the continuation without affecting the termination case.

- **Parameters:**
  - `f`: Transformation function to apply to the value

**Example:**
```dart
final cont = Cont.of(42).map((n) => n * 2);
cont.run((), onThen: print); // prints: 84
```

---

### map0

```dart
Cont<E, A2> map0<A2>(A2 Function() f)
```

Transforms the value inside a `Cont` using a zero-argument function.

Similar to `map` but ignores the current value and computes a new one.

- **Parameters:**
  - `f`: Zero-argument transformation function

**Example:**
```dart
final cont = Cont.of(42).map0(() => 'done');
cont.run((), onThen: print); // prints: done
```

---

### as

```dart
Cont<E, A2> as<A2>(A2 value)
```

Replaces the value inside a `Cont` with a constant.

Discards the current value and replaces it with a fixed value.

- **Parameters:**
  - `value`: The constant value to replace with

**Example:**
```dart
final cont = fetchUser().as('User fetched');
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

## Loops

### asLongAs

```dart
Cont<E, A> asLongAs(bool Function(A value) predicate)
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
final result = fetchData().asLongAs((response) => !response.isReady);

// Retry while value is below threshold
final value = computation().asLongAs((n) => n < 100);

// Retry with exponential backoff
var delay = 100;
final result = attemptOperation()
  .thenTap0(() => Cont.fromDeferred(() {
    delay *= 2;
    return Future.delayed(Duration(milliseconds: delay));
  }))
  .asLongAs((success) => !success && delay < 10000);
```

---

### until

```dart
Cont<E, A> until(bool Function(A value) predicate)
```

Repeatedly executes the continuation until the predicate returns `true`.

Runs the continuation in a loop, testing each result with the predicate. The loop continues while the predicate returns `false`, and stops successfully when the predicate returns `true`.

This is the inverse of `asLongAs` - implemented as `asLongAs((a) => !predicate(a))`. Use this when you want to retry until a condition is met.

- **Parameters:**
  - `predicate`: Function that tests the value. Returns `true` to stop the loop and succeed, or `false` to continue looping

**Example:**
```dart
// Retry until a condition is met
final result = fetchStatus().until((status) => status == 'complete');

// Poll until a threshold is reached
final value = checkProgress().until((progress) => progress >= 100);
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
