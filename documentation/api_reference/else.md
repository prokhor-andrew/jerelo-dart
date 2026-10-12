[Home](../../README.md) > API Reference > Else Channel Operations

# Else Channel Operations

Error path operations for recovery, transformation, and error handling.

---

## Table of Contents

- [Chaining](#chaining)
  - [elseDo](#elsedo)
- [Error Transformation](#error-transformation)
  - [elseMap](#elsemap)
- [More in jerelo_ext](#more-in-jerelo_ext)

---

## Chaining

### elseDo

```dart
Cont<E, F2, A> elseDo<F2>(Cont<E, F2, A> Function(F error) f)
```

Provides a fallback continuation in case of an error.

If the continuation terminates with a typed error, executes the fallback. The fallback may produce a different error type `F2`. If the fallback also terminates, only the fallback's error is propagated.

To accumulate errors from both attempts, use `elseZip` from [jerelo_ext](#more-in-jerelo_ext) instead.

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

## More in jerelo_ext

These operators are not part of core. They are in the [jerelo_ext](https://pub.dev/packages/jerelo_ext) package; import `package:jerelo_ext/jerelo_ext.dart` alongside `package:jerelo/jerelo.dart`.

- Variants: `elseDo0`, `elseDoWithEnv`, `elseDoWithEnv0`, `elseMap0`, `elseMapWithEnv`, `elseMapWithEnv0`, `elseMapTo`
- Side effects: `elseTap` and its variants
- Combining errors: `elseZip` and its variants
- Fire and forget: `elseFork` and its variants
- Promotion: `promote`, `promoteWith` and their variants
- Conditionals: `elseUnless` and its variants
- Retry loops: `elseWhile`, `elseUntil`, `elseForever` and their variants

Core provides [`Cont.tailRecM`](construction.md#conttailrecm) for retry loops, and [`elseUnit`](execution.md#elseunit) to discard the error.
