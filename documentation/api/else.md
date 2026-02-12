# Else Channel Operations

Error path operations for recovery and error handling.

---

## Table of Contents

- [Simple Recovery](#simple-recovery)
  - [recover](#recover)
  - [recover0](#recover0)
  - [recoverWithEnv](#recoverwithenv)
  - [recoverWithEnv0](#recoverwithenv0)
  - [recoverWith](#recoverwith)
- [Chaining](#chaining)
  - [elseDo](#elsedo)
  - [elseDo0](#elsedo0)
  - [elseDoWithEnv](#elsedowithenv)
  - [elseDoWithEnv0](#elsedowithenv0)
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
- [Error Transformation](#error-transformation)
  - [elseMap](#elsemap)
  - [elseMap0](#elsemap0)
  - [elseMapWithEnv](#elsemapwithenv)
  - [elseMapWithEnv0](#elsemapwithenv0)
  - [elseMapTo](#elsemapto)
- [Conditionals](#conditionals)
  - [elseIf](#elseif)
  - [elseIf0](#elseif0)
  - [elseIfWithEnv](#elseifwithenv)
  - [elseIfWithEnv0](#elseifwithenv0)
- [Retry Loops](#retry-loops)
  - [elseWhile](#elsewhile)
  - [elseWhile0](#elsewhile0)
  - [elseWhileWithEnv](#elsewhilewithenv)
  - [elseWhileWithEnv0](#elsewhilewithenv0)
  - [elseUntil](#elseuntil)
  - [elseUntil0](#elseuntil0)
  - [elseUntilWithEnv](#elseuntilwithenv)
  - [elseUntilWithEnv0](#elseuntilwithenv0)

---

## Simple Recovery

### recover

```dart
Cont<E, A> recover(A Function(List<ContError> errors) f)
```

Recovers from termination by computing a replacement value from the errors.

If the continuation terminates, applies `f` to the error list and succeeds with the returned value. This is a convenience over `elseDo` for cases where the recovery logic is a pure function rather than a full continuation.

- **Parameters:**
  - `f`: Function that receives the termination errors and returns a recovery value

**Example:**
```dart
final cont = Cont.terminate<(), int>([ContError.capture('not found')])
  .recover((errors) => -1);

cont.run((), onThen: print); // prints: -1

// Real-world usage
final user = fetchUser(userId)
  .recover((errors) => User.guest());
```

---

### recover0

```dart
Cont<E, A> recover0(A Function() f)
```

Recovers from termination by computing a replacement value, ignoring the errors.

Similar to `recover` but the recovery function takes no arguments.

- **Parameters:**
  - `f`: Zero-argument function that returns a recovery value

**Example:**
```dart
final data = fetchData()
  .recover0(() => <String>[]);
```

---

### recoverWithEnv

```dart
Cont<E, A> recoverWithEnv(A Function(E env, List<ContError> errors) f)
```

Recovers from termination with access to both errors and environment.

Similar to `recover`, but the recovery function receives both the termination errors and the environment. This is useful when recovery logic needs access to configuration or context information.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a recovery value

**Example:**
```dart
final data = fetchData()
  .recoverWithEnv((env, errors) => env.defaultData);
```

---

### recoverWithEnv0

```dart
Cont<E, A> recoverWithEnv0(A Function(E env) f)
```

Recovers from termination with access to the environment only.

Similar to `recoverWithEnv`, but the recovery function only receives the environment and ignores the termination errors.

- **Parameters:**
  - `f`: Function that takes the environment and returns a recovery value

**Example:**
```dart
final value = fetchValue()
  .recoverWithEnv0((env) => env.config.defaultValue);
```

---

### recoverWith

```dart
Cont<E, A> recoverWith(A value)
```

Recovers from termination with a constant fallback value.

If the continuation terminates, succeeds with `value` instead. This is the simplest form of error recovery.

- **Parameters:**
  - `value`: The value to use when the continuation terminates

**Example:**
```dart
final cont = Cont.stop<(), int>([ContError.capture('error')])
  .recoverWith(0);

cont.run((), onThen: print); // prints: 0

// Real-world usage
final count = fetchCount()
  .recoverWith(0);
```

---

## Chaining

### elseDo

```dart
Cont<E, A> elseDo(Cont<E, A> Function(List<ContError> errors) f)
```

Provides a fallback continuation in case of termination.

If the continuation terminates, executes the fallback. If the fallback also terminates, only the fallback's errors are propagated (the original errors are discarded).

To accumulate errors from both attempts, use `elseZip` instead.

- **Parameters:**
  - `f`: Function that receives errors and produces a fallback continuation

**Example:**
```dart
final data = fetchFromPrimary()
  .elseDo((errors) => fetchFromBackup());

// With error inspection
final user = fetchUser(userId)
  .elseDo((errors) {
    if (errors.any((e) => e.error == 'not_found')) {
      return createUser(userId);
    }
    return Cont.terminate(errors);
  });
```

---

### elseDo0

```dart
Cont<E, A> elseDo0(Cont<E, A> Function() f)
```

Provides a zero-argument fallback continuation.

Similar to `elseDo` but doesn't use the error information.

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
Cont<E, A> elseDoWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f)
```

Provides a fallback continuation that has access to both errors and environment.

Similar to `elseDo`, but the fallback function receives both the errors and the environment. This is useful when error recovery needs access to configuration or context from the environment.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a fallback continuation

**Example:**
```dart
final data = fetchData()
  .elseDoWithEnv((env, errors) {
    // Can access both env and errors
    return fetchFromUrl(env.backupUrl);
  });
```

---

### elseDoWithEnv0

```dart
Cont<E, A> elseDoWithEnv0(Cont<E, A> Function(E env) f)
```

Provides a fallback continuation with access to the environment only.

Similar to `elseDoWithEnv`, but the fallback function only receives the environment and ignores the error information. This is useful when error recovery needs access to configuration but doesn't need to inspect the errors.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback continuation

**Example:**
```dart
final data = fetchData()
  .elseDoWithEnv0((env) => fetchFromUrl(env.fallbackUrl));
```

---

## Side Effects

### elseTap

```dart
Cont<E, A> elseTap(Cont<E, A> Function(List<ContError> errors) f)
```

Executes a side-effect continuation on termination, with conditional recovery.

If the continuation terminates, executes the side-effect continuation and waits for it to complete. The behavior depends on the side-effect's outcome:

- If the side-effect succeeds: Recovers from the original termination and returns the side-effect's success value
- If the side-effect terminates: Returns the original errors, ignoring the side-effect's errors

This allows the operation to recover from termination when the side-effect succeeds. If you want to always propagate the original termination regardless of the side-effect's outcome, use `elseFork` instead.

- **Parameters:**
  - `f`: Function that receives the original errors and returns a side-effect continuation

**Example:**
```dart
// Log error and optionally recover
final result = fetchData()
  .elseTap((errors) => logError(errors).map0(() => defaultData));

// Attempt to repair and retry
final result = operation()
  .elseTap((errors) => repairAndRetry());
```

---

### elseTap0

```dart
Cont<E, A> elseTap0(Cont<E, A> Function() f)
```

Executes a zero-argument side-effect continuation on termination, with conditional recovery.

Similar to `elseTap` but ignores the error information. Waits for the side-effect to complete and recovers if it succeeds, or returns the original errors if the side-effect terminates.

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
Cont<E, A> elseTapWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f)
```

Executes a side-effect continuation on termination with access to the environment, with conditional recovery.

Similar to `elseTap`, but the side-effect function receives both the environment and the errors. Waits for the side-effect to complete and recovers if it succeeds, or returns the original errors if the side-effect terminates. This allows error-handling side-effects (like logging or reporting) to access configuration or context information.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseTapWithEnv((env, errors) => env.logger.error(errors));
```

---

### elseTapWithEnv0

```dart
Cont<E, A> elseTapWithEnv0(Cont<E, A> Function(E env) f)
```

Executes a side-effect continuation on termination with access to the environment only, with conditional recovery.

Similar to `elseTapWithEnv`, but the side-effect function only receives the environment and ignores the error information. Waits for the side-effect to complete and recovers if it succeeds, or returns the original errors if the side-effect terminates.

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
Cont<E, A> elseZip(Cont<E, A> Function(List<ContError>) f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Attempts a fallback continuation and combines errors from both attempts.

If the continuation terminates, executes the fallback. If the fallback also terminates, combines errors from both attempts using the provided `combine` function before terminating.

Unlike `elseDo`, which only keeps the second error list, this method accumulates and combines errors from both attempts.

- **Parameters:**
  - `f`: Function that receives original errors and produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

**Example:**
```dart
final result = attempt1()
  .elseZip(
    (errors1) => attempt2(),
    (errors1, errors2) => [...errors1, ...errors2],
  );

// Collect all validation errors
final validated = validatePrimary()
  .elseZip(
    (errors) => validateSecondary(),
    (e1, e2) => [...e1, ...e2],
  );
```

---

### elseZip0

```dart
Cont<E, A> elseZip0(Cont<E, A> Function() f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Zero-argument version of `elseZip`.

Similar to `elseZip` but doesn't use the original error information when producing the fallback continuation.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

**Example:**
```dart
final result = primaryAttempt()
  .elseZip0(
    () => secondaryAttempt(),
    (e1, e2) => [...e1, ...e2],
  );
```

---

### elseZipWithEnv

```dart
Cont<E, A> elseZipWithEnv(Cont<E, A> Function(E env, List<ContError>) f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Attempts a fallback continuation with access to the environment and combines errors.

Similar to `elseZip`, but the fallback function receives both the environment and the original errors. If both the original attempt and fallback fail, their errors are combined using the `combine` function. This is useful when error recovery strategies need access to configuration or context.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

**Example:**
```dart
final result = fetchData()
  .elseZipWithEnv(
    (env, errors) => fetchFromUrl(env.backupUrl),
    (e1, e2) => [...e1, ...e2],
  );
```

---

### elseZipWithEnv0

```dart
Cont<E, A> elseZipWithEnv0(Cont<E, A> Function(E env) f, List<ContError> Function(List<ContError>, List<ContError>) combine)
```

Attempts a fallback continuation with access to the environment only and combines errors.

Similar to `elseZipWithEnv`, but the fallback function only receives the environment and ignores the original error information.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback continuation
  - `combine`: Function to combine error lists from both attempts

**Example:**
```dart
final result = primaryOperation()
  .elseZipWithEnv0(
    (env) => fallbackOperation(env),
    (e1, e2) => [...e1, ...e2],
  );
```

---

## Fire and Forget

### elseFork

```dart
Cont<E, A> elseFork<A2>(Cont<E, A2> Function(List<ContError> errors) f)
```

Executes a side-effect continuation on termination in a fire-and-forget manner.

If the continuation terminates, starts the side-effect continuation without waiting for it to complete. Unlike `elseTap`, this does not wait for the side-effect to finish before propagating the termination. Any errors from the side-effect are silently ignored.

- **Parameters:**
  - `f`: Function that returns a side-effect continuation

**Example:**
```dart
// Log errors asynchronously without blocking
final result = fetchData()
  .elseFork((errors) => logToRemote(errors));

// Send error reports in background
final result = operation()
  .elseFork((errors) => sendErrorReport(errors));
```

---

### elseFork0

```dart
Cont<E, A> elseFork0<A2>(Cont<E, A2> Function() f)
```

Executes a zero-argument side-effect continuation on termination in a fire-and-forget manner.

Similar to `elseFork` but ignores the error information.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseFork0(() => clearCache());
```

---

### elseForkWithEnv

```dart
Cont<E, A> elseForkWithEnv(Cont<E, A> Function(E env, List<ContError> errors) f)
```

Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment.

Similar to `elseFork`, but the side-effect function receives both the environment and the errors. The side-effect is started without waiting for it to complete, and any errors from the side-effect are silently ignored.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and returns a side-effect continuation

**Example:**
```dart
final result = fetchData()
  .elseForkWithEnv((env, errors) => env.errorReporter.send(errors));
```

---

### elseForkWithEnv0

```dart
Cont<E, A> elseForkWithEnv0(Cont<E, A> Function(E env) f)
```

Executes a side-effect continuation on termination in a fire-and-forget manner with access to the environment only.

Similar to `elseForkWithEnv`, but the side-effect function only receives the environment and ignores the error information.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

**Example:**
```dart
final result = operation()
  .elseForkWithEnv0((env) => env.metrics.incrementFailures());
```

---

## Error Transformation

### elseMap

```dart
Cont<E, A> elseMap(List<ContError> Function(List<ContError> errors) f)
```

Transforms termination errors using a pure function.

If the continuation terminates, applies the transformation function to the error list and terminates with the transformed errors. This is useful for enriching, filtering, or transforming error information.

- **Parameters:**
  - `f`: Function that transforms the error list

**Example:**
```dart
final cont = fetchData()
  .elseMap((errors) => errors.map((e) =>
    ContError.capture('Enriched: ${e.error}')
  ).toList());
```

---

### elseMap0

```dart
Cont<E, A> elseMap0(List<ContError> Function() f)
```

Transforms termination errors using a zero-argument function.

Similar to `elseMap` but replaces errors without examining the original error list.

- **Parameters:**
  - `f`: Zero-argument function that produces new errors

**Example:**
```dart
final cont = operation()
  .elseMap0(() => [ContError.capture('Operation failed')]);
```

---

### elseMapWithEnv

```dart
Cont<E, A> elseMapWithEnv(List<ContError> Function(E env, List<ContError> errors) f)
```

Transforms termination errors with access to both errors and environment.

Similar to `elseMap`, but the transformation function receives both the error list and the environment. This is useful when error transformation needs access to configuration or context information.

- **Parameters:**
  - `f`: Function that takes the environment and errors, and produces transformed errors

**Example:**
```dart
final cont = fetchData()
  .elseMapWithEnv((env, errors) =>
    [ContError.capture('${env.serviceName}: ${errors.first.error}')]
  );
```

---

### elseMapWithEnv0

```dart
Cont<E, A> elseMapWithEnv0(List<ContError> Function(E env) f)
```

Transforms termination errors with access to the environment only.

Similar to `elseMapWithEnv`, but the transformation function only receives the environment and ignores the original errors.

- **Parameters:**
  - `f`: Function that takes the environment and produces new errors

**Example:**
```dart
final cont = operation()
  .elseMapWithEnv0((env) =>
    [ContError.capture('Error in ${env.context}')]
  );
```

---

### elseMapTo

```dart
Cont<E, A> elseMapTo(List<ContError> errors)
```

Replaces termination errors with a fixed error list.

If the continuation terminates, replaces the errors with the provided list. This is the simplest form of error transformation.

- **Parameters:**
  - `errors`: The error list to replace with

**Example:**
```dart
final cont = operation()
  .elseMapTo([ContError.capture('Generic error')]);
```

---

## Conditionals

### elseIf

```dart
Cont<E, A> elseIf(bool Function(List<ContError> errors) predicate, A value)
```

Conditionally recovers from termination when the predicate is satisfied.

Filters termination based on the predicate. If the predicate returns `true`, the continuation recovers with the provided value. If the predicate returns `false`, the continuation continues terminating with the original errors.

This is the error-channel counterpart to `thenIf`. While `thenIf` filters values on the success channel, `elseIf` filters errors on the termination channel and provides conditional recovery.

This is useful for recovering from specific error conditions while letting other errors propagate through.

- **Parameters:**
  - `predicate`: Function that tests the error list
  - `value`: The value to recover with when the predicate returns `true`

**Example:**
```dart
final cont = Cont.terminate<(), int>([ContError.capture('not found')])
  .elseIf((errors) => errors.first.error == 'not found', 42);
// Recovers with 42

final cont2 = Cont.terminate<(), int>([ContError.capture('fatal error')])
  .elseIf((errors) => errors.first.error == 'not found', 42);
// Continues terminating with 'fatal error'

// Real-world usage
final user = fetchUser(userId)
  .elseIf(
    (errors) => errors.any((e) => e.error is UserNotFoundException),
    User.guest(),
  );
```

---

### elseIf0

```dart
Cont<E, A> elseIf0(bool Function() predicate, A value)
```

Conditionally recovers based on a zero-argument predicate.

Similar to `elseIf` but the predicate doesn't examine the errors.

- **Parameters:**
  - `predicate`: Zero-argument function that determines whether to recover
  - `value`: The value to recover with when the predicate returns `true`

**Example:**
```dart
var shouldRecover = true;
final cont = operation()
  .elseIf0(() => shouldRecover, defaultValue);
```

---

### elseIfWithEnv

```dart
Cont<E, A> elseIfWithEnv(bool Function(E env, List<ContError> errors) predicate, A value)
```

Conditionally recovers with access to both errors and environment.

Similar to `elseIf`, but the predicate function receives both the termination errors and the environment. This is useful when recovery logic needs access to configuration or context information.

- **Parameters:**
  - `predicate`: Function that takes the environment and errors, and determines whether to recover
  - `value`: The value to recover with when the predicate returns `true`

**Example:**
```dart
final result = fetchData()
  .elseIfWithEnv(
    (env, errors) => env.allowRecovery && errors.length < 3,
    defaultData,
  );
```

---

### elseIfWithEnv0

```dart
Cont<E, A> elseIfWithEnv0(bool Function(E env) predicate, A value)
```

Conditionally recovers with access to the environment only.

Similar to `elseIfWithEnv`, but the predicate only receives the environment and ignores the errors.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines whether to recover
  - `value`: The value to recover with when the predicate returns `true`

**Example:**
```dart
final result = operation()
  .elseIfWithEnv0(
    (env) => env.gracefulDegradation,
    fallbackValue,
  );
```

---

## Retry Loops

### elseWhile

```dart
Cont<E, A> elseWhile(bool Function(List<ContError> errors) predicate)
```

Repeatedly retries the continuation while the predicate returns `true` on termination errors.

If the continuation terminates, tests the errors with the predicate. The loop continues retrying as long as the predicate returns `true`, and stops when the predicate returns `false` (propagating the termination) or when the continuation succeeds.

This is useful for retry logic with error-based conditions, such as retrying while specific transient errors occur.

- **Parameters:**
  - `predicate`: Function that tests the termination errors. Returns `true` to retry, or `false` to stop and propagate the termination

**Example:**
```dart
// Retry while getting transient errors
final result = apiCall()
  .elseWhile((errors) => errors.first.error is TransientError);

// Retry while rate-limited
final data = fetchData()
  .elseWhile((errors) =>
    errors.any((e) => e.error == 'rate_limit')
  );
```

---

### elseWhile0

```dart
Cont<E, A> elseWhile0(bool Function() predicate)
```

Repeatedly retries while a zero-argument predicate returns `true`.

Similar to `elseWhile` but the predicate doesn't examine the errors.

- **Parameters:**
  - `predicate`: Zero-argument function that determines whether to retry

**Example:**
```dart
var shouldRetry = true;
final result = operation()
  .elseWhile0(() => shouldRetry);
```

---

### elseWhileWithEnv

```dart
Cont<E, A> elseWhileWithEnv(bool Function(E env, List<ContError> errors) predicate)
```

Repeatedly retries with access to both errors and environment.

Similar to `elseWhile`, but the predicate function receives both the termination errors and the environment. This is useful when retry logic needs access to configuration or context information.

- **Parameters:**
  - `predicate`: Function that takes the environment and errors, and determines whether to retry

**Example:**
```dart
final result = apiCall()
  .elseWhileWithEnv((env, errors) =>
    errors.first.error is TransientError &&
    env.retryCount < env.maxRetries
  );
```

---

### elseWhileWithEnv0

```dart
Cont<E, A> elseWhileWithEnv0(bool Function(E env) predicate)
```

Repeatedly retries with access to the environment only.

Similar to `elseWhileWithEnv`, but the predicate only receives the environment and ignores the errors.

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
Cont<E, A> elseUntil(bool Function(List<ContError> errors) predicate)
```

Repeatedly retries the continuation until the predicate returns `true` on termination errors.

If the continuation terminates, tests the errors with the predicate. The loop continues retrying while the predicate returns `false`, and stops when the predicate returns `true` (propagating the termination) or when the continuation succeeds.

This is the inverse of `elseWhile` - implemented as `elseWhile((errors) => !predicate(errors))`. Use this when you want to retry until a specific error condition is met.

- **Parameters:**
  - `predicate`: Function that tests the termination errors. Returns `true` to stop and propagate the termination, or `false` to continue retrying

**Example:**
```dart
// Retry until a fatal error occurs
final result = apiCall()
  .elseUntil((errors) => errors.first.error is FatalError);

// Retry until max attempts reached
var attempts = 0;
final data = operation()
  .elseTap0(() => Cont.of(attempts++))
  .elseUntil((errors) => attempts >= 5);
```

---

### elseUntil0

```dart
Cont<E, A> elseUntil0(bool Function() predicate)
```

Repeatedly retries until a zero-argument predicate returns `true`.

Similar to `elseUntil` but the predicate doesn't examine the errors.

- **Parameters:**
  - `predicate`: Zero-argument function that determines when to stop retrying

**Example:**
```dart
var maxAttemptsReached = false;
final result = operation()
  .elseUntil0(() => maxAttemptsReached);
```

---

### elseUntilWithEnv

```dart
Cont<E, A> elseUntilWithEnv(bool Function(E env, List<ContError> errors) predicate)
```

Repeatedly retries with access to both errors and environment.

Similar to `elseUntil`, but the predicate function receives both the termination errors and the environment. This is useful when retry logic needs access to configuration or context information.

- **Parameters:**
  - `predicate`: Function that takes the environment and errors, and determines when to stop

**Example:**
```dart
final result = apiCall()
  .elseUntilWithEnv((env, errors) =>
    errors.first.error is FatalError ||
    env.currentTime.isAfter(env.deadline)
  );
```

---

### elseUntilWithEnv0

```dart
Cont<E, A> elseUntilWithEnv0(bool Function(E env) predicate)
```

Repeatedly retries with access to the environment only.

Similar to `elseUntilWithEnv`, but the predicate only receives the environment and ignores the errors.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines when to stop

**Example:**
```dart
final result = operation()
  .elseUntilWithEnv0((env) => env.timeoutReached);
```
