[Home](../../README.md) > API Reference > Crash Channel Operations

# Crash Channel Operations

Crash recovery, side effects, and control flow for unexpected exceptions.

Unlike typed errors on the else channel (`F`), crashes represent unexpected exceptions — failures that were not part of the expected control flow. The crash channel provides operators symmetric to the then and else channels for handling these exceptional situations.

---

## Table of Contents

- [Recovery](#recovery)
  - [crashDo](#crashdo)
  - [crashDo0](#crashdo0)
  - [crashDoWithEnv](#crashdowithenv)
  - [crashDoWithEnv0](#crashdowithenv0)
- [Side Effects](#side-effects)
  - [crashTap](#crashtap)
  - [crashTap0](#crashtap0)
  - [crashTapWithEnv](#crashtapwithenv)
  - [crashTapWithEnv0](#crashtapwithenv0)
- [Combining Crashes](#combining-crashes)
  - [crashZip](#crashzip)
  - [crashZip0](#crashzip0)
  - [crashZipWithEnv](#crashzipwithenv)
  - [crashZipWithEnv0](#crashzipwithenv0)
- [Fire and Forget](#fire-and-forget)
  - [crashFork](#crashfork)
  - [crashFork0](#crashfork0)
  - [crashForkWithEnv](#crashforkwithenv)
  - [crashForkWithEnv0](#crashforkwithenv0)
- [Recover to Then](#recover-to-then)
  - [crashRecoverThen](#crashrecoverthen)
  - [crashRecoverThen0](#crashrecoverthen0)
  - [crashRecoverThenWithEnv](#crashrecoverthenWithenv)
  - [crashRecoverThenWithEnv0](#crashrecoverthenWithenv0)
  - [crashRecoverThenWith](#crashrecoverThenWith)
- [Recover to Else](#recover-to-else)
  - [crashRecoverElse](#crashrecoverelse)
  - [crashRecoverElse0](#crashrecoverelse0)
  - [crashRecoverElseWithEnv](#crashrecoverelseWithenv)
  - [crashRecoverElseWithEnv0](#crashrecoverelseWithenv0)
  - [crashRecoverElseWith](#crashrecoverelseWith)
- [Conditionals](#conditionals)
  - [crashUnlessThen](#crashunlessthen)
  - [crashUnlessThen0](#crashunlessthen0)
  - [crashUnlessThenWithEnv](#crashunlessthenWithenv)
  - [crashUnlessThenWithEnv0](#crashunlessthenWithenv0)
  - [crashUnlessElse](#crashunlesselse)
  - [crashUnlessElse0](#crashunlesselse0)
  - [crashUnlessElseWithEnv](#crashunlesselseWithenv)
  - [crashUnlessElseWithEnv0](#crashunlesselseWithenv0)
- [Retry Loops](#retry-loops)
  - [crashWhile](#crashwhile)
  - [crashWhile0](#crashwhile0)
  - [crashWhileWithEnv](#crashwhilewithenv)
  - [crashWhileWithEnv0](#crashwhilewithenv0)
  - [crashUntil](#crashuntil)
  - [crashUntil0](#crashuntil0)
  - [crashUntilWithEnv](#crashuntilwithenv)
  - [crashUntilWithEnv0](#crashuntilwithenv0)
  - [crashForever](#crashforever)

---

## Recovery

### crashDo

```dart
Cont<E, F, A> crashDo(Cont<E, F, A> Function(ContCrash crash) f)
```

Provides a fallback continuation in case of a crash.

If the continuation crashes, executes the fallback. This is the primary crash recovery mechanism.

- **Parameters:**
  - `f`: Function that receives the crash and produces a fallback continuation

**Example:**
```dart
final result = riskyOperation()
  .crashDo((crash) => safeAlternative());
```

---

### crashDo0

```dart
Cont<E, F, A> crashDo0(Cont<E, F, A> Function() f)
```

Provides a zero-argument fallback continuation on crash.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation

**Example:**
```dart
final result = riskyOperation()
  .crashDo0(() => safeAlternative());
```

---

### crashDoWithEnv

```dart
Cont<E, F, A> crashDoWithEnv(Cont<E, F, A> Function(E env, ContCrash crash) f)
```

Provides a fallback continuation on crash with access to both environment and crash.

- **Parameters:**
  - `f`: Function that takes the environment and crash, and returns a fallback continuation

**Example:**
```dart
final result = riskyOperation()
  .crashDoWithEnv((env, crash) => env.fallbackService.handle(crash));
```

---

### crashDoWithEnv0

```dart
Cont<E, F, A> crashDoWithEnv0(Cont<E, F, A> Function(E env) f)
```

Provides a fallback continuation on crash with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a fallback continuation

**Example:**
```dart
final result = riskyOperation()
  .crashDoWithEnv0((env) => env.fallbackService.getDefault());
```

---

## Side Effects

### crashTap

```dart
Cont<E, F, A> crashTap(Cont<E, F, A> Function(ContCrash crash) f)
```

Executes a side-effect continuation on crash, with conditional recovery.

If the side-effect succeeds, recovers from the crash. If the side-effect itself crashes, the original crash propagates.

- **Parameters:**
  - `f`: Function that receives the crash and returns a side-effect continuation

**Example:**
```dart
final result = riskyOperation()
  .crashTap((crash) => logCrash(crash));
```

---

### crashTap0

```dart
Cont<E, F, A> crashTap0(Cont<E, F, A> Function() f)
```

Executes a zero-argument side-effect continuation on crash.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

---

### crashTapWithEnv

```dart
Cont<E, F, A> crashTapWithEnv(Cont<E, F, A> Function(E env, ContCrash crash) f)
```

Executes a side-effect on crash with access to both environment and crash.

- **Parameters:**
  - `f`: Function that takes the environment and crash, and returns a side-effect continuation

---

### crashTapWithEnv0

```dart
Cont<E, F, A> crashTapWithEnv0(Cont<E, F, A> Function(E env) f)
```

Executes a side-effect on crash with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

---

## Combining Crashes

### crashZip

```dart
Cont<E, F, A> crashZip(Cont<E, F, A> Function(ContCrash crash) f)
```

Attempts a fallback on crash and merges crashes if the fallback also crashes.

If the continuation crashes and the fallback also crashes, both crashes are merged using `ContCrash.merge`.

- **Parameters:**
  - `f`: Function that receives the crash and produces a fallback continuation

**Example:**
```dart
final result = attempt1()
  .crashZip((crash) => attempt2());
// If both crash, crashes are merged
```

---

### crashZip0

```dart
Cont<E, F, A> crashZip0(Cont<E, F, A> Function() f)
```

Zero-argument version of `crashZip`.

- **Parameters:**
  - `f`: Zero-argument function that produces a fallback continuation

---

### crashZipWithEnv

```dart
Cont<E, F, A> crashZipWithEnv(Cont<E, F, A> Function(E env, ContCrash crash) f)
```

Attempts a fallback on crash with access to the environment, merging crashes.

- **Parameters:**
  - `f`: Function that takes the environment and crash, and produces a fallback

---

### crashZipWithEnv0

```dart
Cont<E, F, A> crashZipWithEnv0(Cont<E, F, A> Function(E env) f)
```

Attempts a fallback on crash with access to the environment only, merging crashes.

- **Parameters:**
  - `f`: Function that takes the environment and produces a fallback

---

## Fire and Forget

### crashFork

```dart
Cont<E, F, A> crashFork<F2, A2>(Cont<E, F2, A2> Function(ContCrash crash) f)
```

Executes a side-effect on crash in a fire-and-forget manner.

Does not wait for the side-effect to complete. The forked continuation may have different error and value types since its result is discarded.

- **Parameters:**
  - `f`: Function that receives the crash and returns a side-effect continuation

**Example:**
```dart
final result = riskyOperation()
  .crashFork((crash) => reportCrash(crash));
```

---

### crashFork0

```dart
Cont<E, F, A> crashFork0<F2, A2>(Cont<E, F2, A2> Function() f)
```

Zero-argument fire-and-forget on crash.

- **Parameters:**
  - `f`: Zero-argument function that returns a side-effect continuation

---

### crashForkWithEnv

```dart
Cont<E, F, A> crashForkWithEnv<F2, A2>(Cont<E, F2, A2> Function(E env, ContCrash crash) f)
```

Fire-and-forget on crash with access to the environment.

- **Parameters:**
  - `f`: Function that takes the environment and crash, and returns a side-effect continuation

---

### crashForkWithEnv0

```dart
Cont<E, F, A> crashForkWithEnv0<F2, A2>(Cont<E, F2, A2> Function(E env) f)
```

Fire-and-forget on crash with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a side-effect continuation

---

## Recover to Then

### crashRecoverThen

```dart
Cont<E, F, A> crashRecoverThen(A Function(ContCrash crash) f)
```

Recovers from a crash by computing a successful value.

- **Parameters:**
  - `f`: Function that receives the crash and returns a recovery value

**Example:**
```dart
final result = riskyOperation()
  .crashRecoverThen((crash) => defaultValue);
```

---

### crashRecoverThen0

```dart
Cont<E, F, A> crashRecoverThen0(A Function() f)
```

Recovers from a crash with a zero-argument value computation.

- **Parameters:**
  - `f`: Zero-argument function that returns a recovery value

---

### crashRecoverThenWithEnv

```dart
Cont<E, F, A> crashRecoverThenWithEnv(A Function(E env, ContCrash crash) f)
```

Recovers from a crash to a value with access to both environment and crash.

- **Parameters:**
  - `f`: Function that takes the environment and crash, and returns a recovery value

---

### crashRecoverThenWithEnv0

```dart
Cont<E, F, A> crashRecoverThenWithEnv0(A Function(E env) f)
```

Recovers from a crash to a value with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns a recovery value

---

### crashRecoverThenWith

```dart
Cont<E, F, A> crashRecoverThenWith(A value)
```

Recovers from a crash with a constant value.

- **Parameters:**
  - `value`: The value to recover with

**Example:**
```dart
final result = riskyOperation()
  .crashRecoverThenWith(0);
```

---

## Recover to Else

### crashRecoverElse

```dart
Cont<E, F, A> crashRecoverElse(F Function(ContCrash crash) f)
```

Recovers from a crash by converting it to a typed error.

- **Parameters:**
  - `f`: Function that receives the crash and returns an error value

**Example:**
```dart
final result = riskyOperation()
  .crashRecoverElse((crash) => 'Unexpected: ${crash}');
```

---

### crashRecoverElse0

```dart
Cont<E, F, A> crashRecoverElse0(F Function() f)
```

Recovers from a crash to an error with a zero-argument computation.

- **Parameters:**
  - `f`: Zero-argument function that returns an error value

---

### crashRecoverElseWithEnv

```dart
Cont<E, F, A> crashRecoverElseWithEnv(F Function(E env, ContCrash crash) f)
```

Recovers from a crash to an error with access to both environment and crash.

- **Parameters:**
  - `f`: Function that takes the environment and crash, and returns an error value

---

### crashRecoverElseWithEnv0

```dart
Cont<E, F, A> crashRecoverElseWithEnv0(F Function(E env) f)
```

Recovers from a crash to an error with access to the environment only.

- **Parameters:**
  - `f`: Function that takes the environment and returns an error value

---

### crashRecoverElseWith

```dart
Cont<E, F, A> crashRecoverElseWith(F error)
```

Recovers from a crash with a constant error value.

- **Parameters:**
  - `error`: The error to recover with

**Example:**
```dart
final result = riskyOperation()
  .crashRecoverElseWith('Operation crashed');
```

---

## Conditionals

### crashUnlessThen

```dart
Cont<E, F, A> crashUnlessThen(
  bool Function(ContCrash crash) predicate, {
  required A fallback,
})
```

Conditionally recovers from a crash to a value unless the predicate is satisfied.

If the predicate returns `false`, recovers with the `fallback` value. If `true`, the crash continues to propagate.

- **Parameters:**
  - `predicate`: Function that tests the crash. Returns `true` to keep crashing, `false` to recover
  - `fallback`: The value to recover with

**Example:**
```dart
final result = riskyOperation()
  .crashUnlessThen(
    (crash) => crash is NormalCrash && crash.error is OutOfMemoryError,
    fallback: defaultValue,
  );
```

---

### crashUnlessThen0

```dart
Cont<E, F, A> crashUnlessThen0(
  bool Function() predicate, {
  required A fallback,
})
```

Conditionally recovers to a value based on a zero-argument predicate.

- **Parameters:**
  - `predicate`: Zero-argument function. Returns `true` to keep crashing, `false` to recover
  - `fallback`: The value to recover with

---

### crashUnlessThenWithEnv

```dart
Cont<E, F, A> crashUnlessThenWithEnv(
  bool Function(E env, ContCrash crash) predicate, {
  required A fallback,
})
```

Conditionally recovers to a value with access to both environment and crash.

- **Parameters:**
  - `predicate`: Function that takes the environment and crash
  - `fallback`: The value to recover with

---

### crashUnlessThenWithEnv0

```dart
Cont<E, F, A> crashUnlessThenWithEnv0(
  bool Function(E env) predicate, {
  required A fallback,
})
```

Conditionally recovers to a value with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment
  - `fallback`: The value to recover with

---

### crashUnlessElse

```dart
Cont<E, F, A> crashUnlessElse(
  bool Function(ContCrash crash) predicate, {
  required F fallback,
})
```

Conditionally recovers from a crash to a typed error unless the predicate is satisfied.

If the predicate returns `false`, terminates with the `fallback` error. If `true`, the crash continues to propagate.

- **Parameters:**
  - `predicate`: Function that tests the crash. Returns `true` to keep crashing, `false` to convert to error
  - `fallback`: The error to terminate with

**Example:**
```dart
final result = riskyOperation()
  .crashUnlessElse(
    (crash) => crash is NormalCrash && crash.error is OutOfMemoryError,
    fallback: 'Operation failed unexpectedly',
  );
```

---

### crashUnlessElse0

```dart
Cont<E, F, A> crashUnlessElse0(
  bool Function() predicate, {
  required F fallback,
})
```

Conditionally converts crash to error based on a zero-argument predicate.

- **Parameters:**
  - `predicate`: Zero-argument function. Returns `true` to keep crashing, `false` to convert to error
  - `fallback`: The error to terminate with

---

### crashUnlessElseWithEnv

```dart
Cont<E, F, A> crashUnlessElseWithEnv(
  bool Function(E env, ContCrash crash) predicate, {
  required F fallback,
})
```

Conditionally converts crash to error with access to both environment and crash.

- **Parameters:**
  - `predicate`: Function that takes the environment and crash
  - `fallback`: The error to terminate with

---

### crashUnlessElseWithEnv0

```dart
Cont<E, F, A> crashUnlessElseWithEnv0(
  bool Function(E env) predicate, {
  required F fallback,
})
```

Conditionally converts crash to error with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment
  - `fallback`: The error to terminate with

---

## Retry Loops

### crashWhile

```dart
Cont<E, F, A> crashWhile(bool Function(ContCrash crash) predicate)
```

Repeatedly retries the continuation while the predicate returns `true` on crashes.

The loop continues while the predicate returns `true` and stops when `false` (propagating the crash) or when the continuation succeeds or terminates with an error.

- **Parameters:**
  - `predicate`: Function that tests the crash. Returns `true` to retry, `false` to stop

**Example:**
```dart
final result = flakeyOperation()
  .crashWhile((crash) => crash is NormalCrash && crash.error is TimeoutException);
```

---

### crashWhile0

```dart
Cont<E, F, A> crashWhile0(bool Function() predicate)
```

Repeatedly retries on crash while a zero-argument predicate returns `true`.

- **Parameters:**
  - `predicate`: Zero-argument function that determines whether to retry

---

### crashWhileWithEnv

```dart
Cont<E, F, A> crashWhileWithEnv(bool Function(E env, ContCrash crash) predicate)
```

Repeatedly retries on crash with access to both environment and crash.

- **Parameters:**
  - `predicate`: Function that takes the environment and crash, and determines whether to retry

---

### crashWhileWithEnv0

```dart
Cont<E, F, A> crashWhileWithEnv0(bool Function(E env) predicate)
```

Repeatedly retries on crash with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines whether to retry

---

### crashUntil

```dart
Cont<E, F, A> crashUntil(bool Function(ContCrash crash) predicate)
```

Repeatedly retries the continuation until the predicate returns `true` on crashes.

The inverse of `crashWhile`. The loop continues while `false` and stops when `true`.

- **Parameters:**
  - `predicate`: Function that tests the crash. Returns `true` to stop, `false` to retry

---

### crashUntil0

```dart
Cont<E, F, A> crashUntil0(bool Function() predicate)
```

Repeatedly retries until a zero-argument predicate returns `true`.

- **Parameters:**
  - `predicate`: Zero-argument function that determines when to stop

---

### crashUntilWithEnv

```dart
Cont<E, F, A> crashUntilWithEnv(bool Function(E env, ContCrash crash) predicate)
```

Repeatedly retries on crash with access to both environment and crash.

- **Parameters:**
  - `predicate`: Function that takes the environment and crash, and determines when to stop

---

### crashUntilWithEnv0

```dart
Cont<E, F, A> crashUntilWithEnv0(bool Function(E env) predicate)
```

Repeatedly retries on crash with access to the environment only.

- **Parameters:**
  - `predicate`: Function that takes the environment and determines when to stop

---

### crashForever

```dart
Cont<E, F, A> crashForever()
```

Repeatedly retries the continuation on crash indefinitely.

If the continuation crashes, retries it in an infinite loop. The loop only ends if the continuation succeeds or terminates with a typed error.

This is useful for operations that must recover from any crash, such as resilient network connections.

**Example:**
```dart
final resilient = connectToServer()
  .crashForever();
```
