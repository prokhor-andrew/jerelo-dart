[Home](../../README.md) > API Reference > Else Channel Operations

# Else Channel Operations

Error path operations for recovery, transformation, and error handling.

---

## Table of Contents

- [Chaining](#chaining)
  - [elseDo](#elsedo)
  - [elseDo0](#elsedo0)
  - [elseDoWithEnv](#elsedowithenv)
  - [elseDoWithEnv0](#elsedowithenv0)
- [Error Transformation](#error-transformation)
  - [elseMap](#elsemap)
  - [elseMap0](#elsemap0)
  - [elseMapWithEnv](#elsemapwithenv)
  - [elseMapWithEnv0](#elsemapwithenv0)
  - [elseMapTo](#elsemapto)
- [Side Effects](#side-effects)
  - [elseTap](#elsetap)
  - [elseTap0](#elsetap0)
  - [elseTapWithEnv](#elsetapwithenv)
  - [elseTapWithEnv0](#elsetapwithenv0)
- [Combining Errors](#combining-errors)
  - [elseZip](#elsezip)
  - [elseZip0](#elsezip0)
  - [elseZipWithEnv](#elsezipwithenv)
  - [elseZipWithEnv0](#elsezipwithenv0)
- [Fire and Forget](#fire-and-forget)
  - [elseFork](#elsefork)
  - [elseFork0](#elsefork0)
  - [elseForkWithEnv](#elseforkwithenv)
  - [elseForkWithEnv0](#elseforkwithenv0)
- [Promotion](#promotion)
  - [promote](#promote)
  - [promote0](#promote0)
  - [promoteWithEnv](#promotewithenv)
  - [promoteWithEnv0](#promotewithenv0)
  - [promoteWith](#promotewith)
- [Conditionals](#conditionals)
  - [elseUnless](#elseunless)
  - [elseUnless0](#elseunless0)
  - [elseUnlessWithEnv](#elseunlesswithenv)
  - [elseUnlessWithEnv0](#elseunlesswithenv0)
- [Retry Loops](#retry-loops)
  - [elseWhile](#elsewhile)
  - [elseWhile0](#elsewhile0)
  - [elseWhileWithEnv](#elsewhilewithenv)
  - [elseWhileWithEnv0](#elsewhilewithenv0)
  - [elseUntil](#elseuntil)
  - [elseUntil0](#elseuntil0)
  - [elseUntilWithEnv](#elseuntilwithenv)
  - [elseUntilWithEnv0](#elseuntilwithenv0)
  - [elseForever](#elseforever)

---

## Chaining

### elseDo

```dart
Cont<E, F2, A> elseDo<F2>(Cont<E, F2, A> Function(F error) f)
```

Provides a fallback continuation in case of an error.

If the continuation terminates with a typed error, executes the fallback. The fallback may produce a different error type `F2`. If the fallback also terminates, only the fallback's error is propagated.

To accumulate errors from both attempts, use `elseZip` instead.

- **Parameters:**
  - `f`: Function that receives the error and produces a fallback continuation

**Example:**
```dart
final data = fetchFromPrimary()
  .elseDo((error) => fetchFromBackup());

final user = fetchUser(userId)
  .elseDo((error) {
    if (error == 'not_found') return createUser(userId);
    return Cont.error(error);
  });
```

---

### elseDo0

```dart
Cont<E, F2, A> elseDo0<F2>(Cont<E, F2, A> Function() f)
```

Provides a zero-argument fallback continuation.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation

**Example:**
```dart
final data = fetchFromPrimary()
  .elseDo0(() => fetchFromBackup());
```

---

### elseDoWithEnv

```dart
Cont<E, F2, A> elseDoWithEnv<F2>(Cont<E, F2, A> Function(E env, F error) f)
```

Provides a fallback continuation with access to both error and environment.

- **Parameters:**
  - `f`: Function that takes the environment and error, and returns a fallback continuation

**Example:**
```dart
final data = fetchData()
  .elseDoWithEnv((env, error) => fetchFromUrl(env.backupUrl));
```

---

### elseDoWithEnv0

```dart
Cont<E, F2, A> elseDoWithEnv0<F2>(Cont<E, F2, A> Function(E env) f)
```

Provides a fallback continuation with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback continuation

**Example:**
```dart
final data = fetchData()
  .elseDoWithEnv0((env) => fetchFromUrl(env.fallbackUrl));
```

---

## Error Transformation

### elseMap

```dart
Cont<E, F2, A> elseMap<F2>(F2 Function(F error) f)
```

Transforms the error using a pure function.

If the continuation terminates, applies the transformation function to the error and terminates with the transformed error. The error type may change from `F` to `F2`.

- **Parameters:**
  - `f`: Function that transforms the error

**Example:**
```dart
final cont = fetchData()
  .elseMap((error) => 'Enriched: $error');
```

---

### elseMap0

```dart
Cont<E, F2, A> elseMap0<F2>(F2 Function() f)
```

Transforms the error using a zero-argument function.

- **Parameters:**
  - `f`: Zero-argument function that produces a new error

**Example:**
```dart
final cont = operation()
  .elseMap0(() => 'Operation failed');
```

---

### elseMapWithEnv

```dart
Cont<E, F2, A> elseMapWithEnv<F2>(F2 Function(E env, F error) f)
```

Transforms the error with access to both error and environment.

- **Parameters:**
  - `f`: Function that takes the environment and error, and produces a transformed error

**Example:**
```dart
final cont = fetchData()
  .elseMapWithEnv((env, error) => '${env.serviceName}: $error');
```

---

### elseMapWithEnv0

```dart
Cont<E, F2, A> elseMapWithEnv0<F2>(F2 Function(E env) f)
```

Transforms the error with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and produces a new error

**Example:**
```dart
final cont = operation()
  .elseMapWithEnv0((env) => 'Error in ${env.context}');
```

---

### elseMapTo

```dart
Cont<E, F2, A> elseMapTo<F2>(F2 error)
```

Replaces the error with a fixed value.

- **Parameters:**
  - `error`: The error value to replace with

**Example:**
```dart
final cont = operation()
  .elseMapTo('Generic error');
```

---

## Side Effects

### elseTap

```dart
Cont<E, F, A> elseTap<F2>(Cont<E, F2, A> Function(F error) f)
```

Executes a side-effect continuation on error, with conditional recovery.

If the continuation terminates, executes the side-effect continuation. The behavior depends on the side-effect's outcome:

- If the side-effect succeeds: Recovers from the original error and returns the side-effect's success value
- If the side-effect terminates: Returns the original error, ignoring the side-effect's error

If you want fire-and-forget behavior, use `elseFork` instead.

- **Parameters:**
  - `f`: Function that receives the error and returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseTap((error) => logAndRetry());
```

---

### elseTap0

```dart
Cont<E, F, A> elseTap0<F2>(Cont<E, F2, A> Function() f)
```

Executes a zero-argument side-effect continuation on error.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseTap0(() => clearCache());
```

---

### elseTapWithEnv

```dart
Cont<E, F, A> elseTapWithEnv<F2>(Cont<E, F2, A> Function(E env, F error) f)
```

Executes a side-effect continuation on error with access to the environment.

- **Parameters:**
  - `f`: Function that takes the environment and error, and returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseTapWithEnv((env, error) => env.logger.error(error));
```

---

### elseTapWithEnv0

```dart
Cont<E, F, A> elseTapWithEnv0<F2>(Cont<E, F2, A> Function(E env) f)
```

Executes a side-effect continuation on error with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseTapWithEnv0((env) => env.metrics.incrementErrors());
```

---

## Combining Errors

### elseZip

```dart
Cont<E, F3, A> elseZip<F2, F3>(
  Cont<E, F2, A> Function(F) f,
  F3 Function(F f1, F2 f2) combine,
)
```

Attempts a fallback continuation and combines errors from both attempts.

If the continuation terminates, executes the fallback. If the fallback also terminates, combines errors from both using `combine`. Unlike `elseDo`, which only keeps the fallback's error, this method accumulates errors from both attempts.

- **Parameters:**
  - `f`: Function that receives the original error and produces a fallback continuation
  - `combine`: Function to combine errors from both attempts

**Example:**
```dart
final result = attempt1()
  .elseZip(
    (error1) => attempt2(),
    (e1, e2) => '$e1 and $e2',
  );
```

---

### elseZip0

```dart
Cont<E, F3, A> elseZip0<F2, F3>(
  Cont<E, F2, A> Function() f,
  F3 Function(F f1, F2 f2) combine,
)
```

Zero-argument version of `elseZip`.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation
  - `combine`: Function to combine errors from both attempts

**Example:**
```dart
final result = primaryAttempt()
  .elseZip0(
    () => secondaryAttempt(),
    (e1, e2) => '$e1; $e2',
  );
```

---

### elseZipWithEnv

```dart
Cont<E, F3, A> elseZipWithEnv<F2, F3>(
  Cont<E, F2, A> Function(E env, F) f,
  F3 Function(F f1, F2 f2) combine,
)
```

Attempts a fallback with access to the environment and combines errors.

- **Parameters:**
  - `f`: Function that takes the environment and error, and produces a fallback continuation
  - `combine`: Function to combine errors from both attempts

**Example:**
```dart
final result = fetchData()
  .elseZipWithEnv(
    (env, error) => fetchFromUrl(env.backupUrl),
    (e1, e2) => '$e1; $e2',
  );
```

---

### elseZipWithEnv0

```dart
Cont<E, F3, A> elseZipWithEnv0<F2, F3>(
  Cont<E, F2, A> Function(E env) f,
  F3 Function(F f1, F2 f2) combine,
)
```

Attempts a fallback with access to the environment only and combines errors.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback continuation
  - `combine`: Function to combine errors from both attempts

**Example:**
```dart
final result = primaryOperation()
  .elseZipWithEnv0(
    (env) => fallbackOperation(env),
    (e1, e2) => '$e1; $e2',
  );
```

---

## Fire and Forget

### elseFork

```dart
Cont<E, F, A> elseFork<F2, A2>(
  Cont<E, F2, A2> Function(F error) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a side-effect continuation on error in a fire-and-forget manner.

Unlike `elseTap`, this does not wait for the side-effect to finish before propagating the error. The forked continuation may have different error and value types.

Outcomes from the forked continuation are dispatched to optional callbacks:
- `onPanic`: Called when the side-effect triggers a panic. Defaults to rethrowing.
- `onCrash`: Called when the side-effect crashes. Defaults to ignoring.
- `onElse`: Called when the side-effect terminates with an error. Defaults to ignoring.
- `onThen`: Called when the side-effect succeeds. Defaults to ignoring.

- **Parameters:**
  - `f`: Function that receives the error and returns a side-effect continuation
  - `onPanic`: *(optional)* Handler for panics in the side-effect
  - `onCrash`: *(optional)* Handler for crashes in the side-effect
  - `onElse`: *(optional)* Handler for errors in the side-effect
  - `onThen`: *(optional)* Handler for success in the side-effect

**Example:**
```dart
final result = fetchData()
  .elseFork((error) => logToRemote(error));

// With observation callbacks:
final result2 = fetchData()
  .elseFork(
    (error) => logToRemote(error),
    onElse: (logError) => print('Logging failed: $logError'),
  );
```

---

### elseFork0

```dart
Cont<E, F, A> elseFork0<F2, A2>(
  Cont<E, F2, A2> Function() f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a zero-argument side-effect continuation on error in a fire-and-forget manner.

Accepts the same optional observation callbacks as `elseFork`.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation
  - `onPanic`, `onCrash`, `onElse`, `onThen`: *(optional)* Outcome observation callbacks (see `elseFork`)

**Example:**
```dart
final result = fetchData()
  .elseFork0(() => clearCache());
```

---

### elseForkWithEnv

```dart
Cont<E, F, A> elseForkWithEnv<F2, A2>(
  Cont<E, F2, A2> Function(E env, F error) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a side-effect on error in a fire-and-forget manner with access to the environment.

Accepts the same optional observation callbacks as `elseFork`.

- **Parameters:**
  - `f`: Function that takes the environment and error, and returns a side-effect continuation
  - `onPanic`, `onCrash`, `onElse`, `onThen`: *(optional)* Outcome observation callbacks (see `elseFork`)

**Example:**
```dart
final result = fetchData()
  .elseForkWithEnv((env, error) => env.errorReporter.send(error));
```

---

### elseForkWithEnv0

```dart
Cont<E, F, A> elseForkWithEnv0<F2, A2>(
  Cont<E, F2, A2> Function(E env) f, {
  void Function(NormalCrash crash) onPanic = _panic,
  void Function(ContCrash crash) onCrash = _ignore,
  void Function(F2 error) onElse = _ignore,
  void Function(A2 value) onThen = _ignore,
})
```

Executes a side-effect on error in a fire-and-forget manner with access to the environment only.

Accepts the same optional observation callbacks as `elseFork`.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation
  - `onPanic`, `onCrash`, `onElse`, `onThen`: *(optional)* Outcome observation callbacks (see `elseFork`)

**Example:**
```dart
final result = operation()
  .elseForkWithEnv0((env) => env.metrics.incrementFailures());
```

---

## Promotion

### promote

```dart
Cont<E, F, A> promote(A Function(F error) f)
```

Promotes an error to a successful value.

If the continuation terminates with an error, computes a replacement value from the error. This is the error-channel counterpart of `demote`.

- **Parameters:**
  - `f`: Function that receives the error and returns a recovery value

**Example:**
```dart
final cont = Cont.error<(), String, int>('not found')
  .promote((error) => -1);

cont.run((), onThen: print); // prints: -1
```

---

### promote0

```dart
Cont<E, F, A> promote0(A Function() f)
```

Promotes an error to a successful value, ignoring the error.

- **Parameters:**
  - `f`: Zero-argument function that returns a recovery value

**Example:**
```dart
final data = fetchData()
  .promote0(() => <String>[]);
```

---

### promoteWithEnv

```dart
Cont<E, F, A> promoteWithEnv(A Function(E env, F error) f)
```

Promotes an error with access to both error and environment.

- **Parameters:**
  - `f`: Function that takes the environment and error, and returns a recovery value

**Example:**
```dart
final data = fetchData()
  .promoteWithEnv((env, error) => env.defaultData);
```

---

### promoteWithEnv0

```dart
Cont<E, F, A> promoteWithEnv0(A Function(E env) f)
```

Promotes an error with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a recovery value

**Example:**
```dart
final value = fetchValue()
  .promoteWithEnv0((env) => env.config.defaultValue);
```

---

### promoteWith

```dart
Cont<E, F, A> promoteWith(A value)
```

Promotes an error to a constant fallback value.

- **Parameters:**
  - `value`: The value to use when the continuation terminates

**Example:**
```dart
final cont = Cont.error<(), String, int>('error')
  .promoteWith(0);

cont.run((), onThen: print); // prints: 0
```

---

## Conditionals

### elseUnless

```dart
Cont<E, F, A> elseUnless(
  bool Function(F error) predicate, {
  required A fallback,
})
```

Conditionally recovers from an error unless the predicate is satisfied.

If the predicate returns `false`, the continuation recovers with the `fallback` value. If the predicate returns `true`, the error continues to propagate.

This is the error-channel counterpart of `thenIf`.

- **Parameters:**
  - `predicate`: Function that tests the error. Returns `true` to keep the error, `false` to recover
  - `fallback`: The value to recover with when the predicate returns `false`

**Example:**
```dart
final cont = Cont.error<(), String, int>('not found')
  .elseUnless((error) => error == 'fatal', fallback: 42);
// Recovers with 42 because 'not found' != 'fatal'

final cont2 = Cont.error<(), String, int>('fatal')
  .elseUnless((error) => error == 'fatal', fallback: 42);
// Continues terminating with 'fatal'
```

---

### elseUnless0

```dart
Cont<E, F, A> elseUnless0(
  bool Function() predicate, {
  required A fallback,
})
```

Conditionally recovers based on a zero-argument predicate.

- **Parameters:**
  - `predicate`: Zero-argument function. Returns `true` to keep the error, `false` to recover
  - `fallback`: The value to recover with

**Example:**
```dart
var shouldKeepError = false;
final cont = operation()
  .elseUnless0(() => shouldKeepError, fallback: defaultValue);
```

---

### elseUnlessWithEnv

```dart
Cont<E, F, A> elseUnlessWithEnv(
  bool Function(E env, F error) predicate, {
  required A fallback,
})
```

Conditionally recovers with access to both error and environment.

- **Parameters:**
  - `predicate`: Function that takes the environment and error, and determines whether to keep the error
  - `fallback`: The value to recover with

**Example:**
```dart
final result = fetchData()
  .elseUnlessWithEnv(
    (env, error) => !env.allowRecovery,
    fallback: defaultData,
  );
```

---

### elseUnlessWithEnv0

```dart
Cont<E, F, A> elseUnlessWithEnv0(
  bool Function(E env) predicate, {
  required A fallback,
})
```

Conditionally recovers with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines whether to keep the error
  - `fallback`: The value to recover with

**Example:**
```dart
final result = operation()
  .elseUnlessWithEnv0(
    (env) => !env.gracefulDegradation,
    fallback: fallbackValue,
  );
```

---

## Retry Loops

### elseWhile

```dart
Cont<E, F, A> elseWhile(bool Function(F error) predicate)
```

Repeatedly retries the continuation while the predicate returns `true` on the error.

If the continuation terminates, tests the error with the predicate. The loop continues retrying while `true`, and stops when `false` (propagating the error) or when the continuation succeeds.

- **Parameters:**
  - `predicate`: Function that tests the error. Returns `true` to retry, `false` to stop

**Example:**
```dart
final result = apiCall()
  .elseWhile((error) => error is TransientError);
```

---

### elseWhile0

```dart
Cont<E, F, A> elseWhile0(bool Function() predicate)
```

Repeatedly retries while a zero-argument predicate returns `true`.

- **Parameters:**
  - `predicate`: Zero-argument function that determines whether to retry

**Example:**
```dart
var shouldRetry = true;
final result = operation().elseWhile0(() => shouldRetry);
```

---

### elseWhileWithEnv

```dart
Cont<E, F, A> elseWhileWithEnv(bool Function(E env, F error) predicate)
```

Repeatedly retries with access to both error and environment.

- **Parameters:**
  - `predicate`: Function that takes the environment and error, and determines whether to retry

**Example:**
```dart
final result = apiCall()
  .elseWhileWithEnv((env, error) =>
    error is TransientError && env.retryCount < env.maxRetries);
```

---

### elseWhileWithEnv0

```dart
Cont<E, F, A> elseWhileWithEnv0(bool Function(E env) predicate)
```

Repeatedly retries with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines whether to retry

**Example:**
```dart
final result = operation()
  .elseWhileWithEnv0((env) => !env.shutdownRequested);
```

---

### elseUntil

```dart
Cont<E, F, A> elseUntil(bool Function(F error) predicate)
```

Repeatedly retries the continuation until the predicate returns `true`.

The inverse of `elseWhile`. The loop continues while the predicate returns `false`, and stops when `true`.

- **Parameters:**
  - `predicate`: Function that tests the error. Returns `true` to stop, `false` to retry

**Example:**
```dart
final result = apiCall()
  .elseUntil((error) => error is FatalError);
```

---

### elseUntil0

```dart
Cont<E, F, A> elseUntil0(bool Function() predicate)
```

Repeatedly retries until a zero-argument predicate returns `true`.

- **Parameters:**
  - `predicate`: Zero-argument function that determines when to stop

**Example:**
```dart
var maxAttemptsReached = false;
final result = operation().elseUntil0(() => maxAttemptsReached);
```

---

### elseUntilWithEnv

```dart
Cont<E, F, A> elseUntilWithEnv(bool Function(E env, F error) predicate)
```

Repeatedly retries with access to both error and environment.

- **Parameters:**
  - `predicate`: Function that takes the environment and error, and determines when to stop

**Example:**
```dart
final result = apiCall()
  .elseUntilWithEnv((env, error) =>
    error is FatalError || env.currentTime.isAfter(env.deadline));
```

---

### elseUntilWithEnv0

```dart
Cont<E, F, A> elseUntilWithEnv0(bool Function(E env) predicate)
```

Repeatedly retries with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines when to stop

**Example:**
```dart
final result = operation()
  .elseUntilWithEnv0((env) => env.timeoutReached);
```

---

### elseForever

```dart
Cont<E, Never, A> elseForever()
```

Repeatedly retries the continuation on error indefinitely.

If the continuation terminates, retries it in an infinite loop. The loop only ends if the continuation succeeds or crashes. The return type `Cont<E, Never, A>` indicates that this continuation never produces an error — it either succeeds, or crashes, or retries forever.

This is useful for resilient connections, self-healing systems, and operations that should never give up.

**Example:**
```dart
final connection = connectToServer().elseForever();

final worker = processJob()
  .elseTap((error) => delay(Duration(seconds: 5)))
  .elseForever();
```
