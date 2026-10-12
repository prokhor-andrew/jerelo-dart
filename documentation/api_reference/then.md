[Home](../../README.md) > API Reference > Then Channel Operations

# Then Channel Operations

Success path operations for transforming and chaining.

---

## Table of Contents

- [Basic Transformations](#basic-transformations)
  - [thenMap](#thenmap)
- [Chaining](#chaining)
  - [thenDo](#thendo)
- [More in jerelo_ext](#more-in-jerelo_ext)

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

## More in jerelo_ext

These operators are not part of core. They are in the [jerelo_ext](https://pub.dev/packages/jerelo_ext) package; import `package:jerelo_ext/jerelo_ext.dart` alongside `package:jerelo/jerelo.dart`.

- Variants: `thenMap0`, `thenMapWithEnv`, `thenMapWithEnv0`, `thenMapTo`, `thenDo0`, `thenDoWithEnv`, `thenDoWithEnv0`
- Side effects: `thenTap` and its variants
- Combining values: `thenZip` and its variants
- Fire and forget: `thenFork` and its variants
- Demotion: `demote`, `demoteWith` and their variants
- Conditionals: `thenIf` and its variants
- Loops: `thenWhile`, `thenUntil`, `thenForever` and their variants

Core provides [`Cont.tailRecM`](construction.md#conttailrecm) for loops, and [`thenUnit`](execution.md#thenunit) to discard the value.
