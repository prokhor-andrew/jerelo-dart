# Else Channel Operations

Error path operations for recovery and error handling.

---

## Table of Contents

- [Simple Recovery](#simple-recovery)
  - [recover](#recover)
  - [recover0](#recover0)
  - [fallback](#fallback)
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
- [Conditionals](#conditionals)
  - [elseIf](#elseif)

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

### fallback

```dart
Cont<E, A> fallback(A value)
```

Recovers from termination with a constant fallback value.

If the continuation terminates, succeeds with `value` instead. This is the simplest form of error recovery.

- **Parameters:**
  - `value`: The value to use when the continuation terminates

**Example:**
```dart
final cont = Cont.terminate<(), int>([ContError.capture('error')])
  .fallback(0);

cont.run((), onThen: print); // prints: 0

// Real-world usage
final count = fetchCount()
  .fallback(0);
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
