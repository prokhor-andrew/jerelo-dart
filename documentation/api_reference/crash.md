[Home](../../README.md) > API Reference > Crash Channel Operations

# Crash Channel Operations

Crash recovery for unexpected exceptions.

Unlike typed errors on the else channel (`F`), crashes represent unexpected exceptions — failures that were not part of the expected control flow. Core provides a single crash operator, `crashDo`; the rest of the crash channel operators are in [jerelo_ext](#more-in-jerelo_ext).

---

## Table of Contents

- [Recovery](#recovery)
  - [crashDo](#crashdo)
- [More in jerelo_ext](#more-in-jerelo_ext)

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

## More in jerelo_ext

These operators are not part of core. They are in the [jerelo_ext](https://pub.dev/packages/jerelo_ext) package; import `package:jerelo_ext/jerelo_ext.dart` alongside `package:jerelo/jerelo.dart`.

- Variants: `crashDo0`, `crashDoWithEnv`, `crashDoWithEnv0`
- Side effects: `crashTap` and its variants
- Combining crashes: `crashZip` and its variants
- Fire and forget: `crashFork` and its variants
- Recovery to the then or else channel: `crashRecoverThen`, `crashRecoverElse` and their variants
- Conditionals: `crashUnlessThen`, `crashUnlessElse` and their variants
- Retry loops: `crashWhile`, `crashUntil`, `crashForever` and their variants

Core provides [`Cont.tailRecM`](construction.md#conttailrecm) for retry loops.
