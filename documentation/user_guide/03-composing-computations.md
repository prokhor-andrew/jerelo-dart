[Home](../../README.md) > User Guide

# Composing Computations

Once you can construct and run a `Cont`, the next step is composing computations together. Every operator in Jerelo works on one of three channels — **then** (success), **else** (typed error), or **crash** (unexpected exception).

Jerelo is built on a small set of fundamental operators: `thenMap`, `thenDo`, `elseMap`, `elseDo`, `crashDo`, `flatten`, the `*While` loops and `decorate`, plus the combinators and environment operators covered in the next guides. Everything else in this guide is built from them.

Jerelo also provides derived operators built from them, such as the variants that ignore the value or read the environment (`thenMap0`, `thenMapTo`, `thenDoWithEnv`, …), taps, zips, forks, conditionals and loops. They are listed in the API reference for the [then](../api_reference/then.md), [else](../api_reference/else.md) and [crash](../api_reference/crash.md) channels.

---

## Transforming Data

Use `thenMap` to transform a success value and `elseMap` to transform an error:

```dart
Cont.of(0)
  .thenMap((n) => n + 1)
  .run((), onThen: print); // prints 1

Cont.error<(), String, int>('timeout')
  .elseMap((e) => 'Network error: $e')
  .run((), onElse: print); // prints "Network error: timeout"
```

---

## Chaining Computations

Chaining builds a new computation from the result of the previous one.

**`thenDo`** chains on success, **`elseDo`** chains on error, and **`crashDo`** chains on crash:

```dart
Cont.of(0)
  .thenDo((n) => Cont.of(n + 1))
  .run((), onThen: print); // prints 1

Cont.error('not found')
  .elseDo((error) => Cont.of(42)) // recover
  .run((), onThen: print); // prints 42

someCont.crashDo((crash) => Cont.of(0)) // recover from crash
  .run((), onThen: print);
```

### Side Effects

For a synchronous side effect, such as logging, do it inside `thenMap` and return the value unchanged:

```dart
Cont.of(42)
  .thenMap((n) {
    print('got $n');
    return n;
  })
  .run((), onThen: print); // prints "got 42", then 42
```

For an effect that is itself a `Cont`, chain it with `thenDo` and map its result back to the original value:

```dart
fetchUser(id)
  .thenDo((user) => writeToCache(user).thenMap((_) => user));
```

Taps ([`thenTap`](../api_reference/then.md#thentap), [`elseTap`](../api_reference/else.md#elsetap), [`crashTap`](../api_reference/crash.md#crashtap)), zips and forks wrap these patterns.

### Crash Recovery

`crashDo` can turn a crash into a success value or a typed error:

```dart
someCont
  .crashDo((crash) => Cont.of(0)) // crash → success
  .run((), onThen: print);

someCont
  .crashDo((crash) => Cont.error('Unexpected: $crash')) // crash → typed error
  .run((), onElse: print);
```

### Flattening

`flatten` collapses a nested `Cont<E, F, Cont<E, F, A>>` into `Cont<E, F, A>`:

```dart
nested.flatten().run((), onThen: print);
```

### Reading the Environment

Use `Cont.askThen` inside a chain to read the environment. See the [Environment Management](05-environment.md) guide for details.

---

## Conditionals

Branch inside `thenDo` or `elseDo` by returning `Cont.of` for one outcome and `Cont.error` for the other:

```dart
Cont.of<(), String, int>(5)
  .thenDo<int>((n) => n > 3 ? Cont.of(n) : Cont.error('too small'))
  .run((), onThen: print); // prints 5

Cont.of<(), String, int>(2)
  .thenDo<int>((n) => n > 3 ? Cont.of(n) : Cont.error('too small'))
  .run((), onElse: print); // prints "too small"
```

Combine it with `elseDo` to build an if-then-else:

```dart
Cont.of<(), String, int>(5)
  .thenDo<int>((n) => n > 3 ? Cont.of(n) : Cont.error('not greater'))
  .thenDo((n) => Cont.of("$n is big"))
  .elseDo((_) => Cont.of("too small"))
  .run((), onThen: print); // prints "5 is big"
```

Without the explicit `<int>`, Dart cannot infer the value type of `Cont.error(...)` and the result becomes `dynamic`.

[`thenIf`](../api_reference/then.md#thenif), [`elseUnless`](../api_reference/else.md#elseunless), [`crashUnlessThen`](../api_reference/crash.md#crashunlessthen) and [`crashUnlessElse`](../api_reference/crash.md#crashunlesselse) wrap this pattern.

---

## Loops

Loops run a computation again and again until a condition says to stop. Each channel has its own: `thenWhile`/`thenUntil` repeat after a value, and `elseWhile`/`elseUntil` and `crashWhile`/`crashUntil` retry after an error or a crash. Every iteration reruns the whole computation the loop is called on. The loops are stack-safe, so they can run any number of iterations, even when the steps complete synchronously. So is plain recursion with `thenDo` and the other operators: see [Stack Safety](../api_reference/execution.md#stack-safety).

```dart
final Cont<(), Never, int> firstBig = Cont.of<(), Never, ()>(())
  .thenMap((_) => Random().nextInt(10))
  .thenWhile((n) => n <= 5);

firstBig.run((), onThen: print); // prints the first value > 5
```

Retries use the else loops. To count attempts, keep the counter in `Cont.fromDeferred`, so each run starts from the first attempt:

```dart
Cont<(), String, Data> fetchWithRetry(int maxAttempts) {
  return Cont.fromDeferred(() {
    var attempt = 1;
    return fetchData().elseWhile((_) => attempt++ < maxAttempts);
  });
}
```

To loop until something else stops it, use a predicate that is always true, such as `thenWhile((_) => true)`; the loop then ends on another channel or after a cancel. See the [then](../api_reference/then.md#loops), [else](../api_reference/else.md#retry-loops) and [crash](../api_reference/crash.md#retry-loops) loops.

---

## Switching Channels

`thenDo` can move a success to the else channel, and `elseDo` can move an error to the then channel:

```dart
Cont.of<(), String, int>(42)
  .thenDo((n) => Cont.error("Value $n not allowed"))
  .run((), onElse: print); // prints "Value 42 not allowed"

Cont.error<(), String, int>('fallback')
  .elseDo((_) => Cont.of(0))
  .run((), onThen: print); // prints 0
```

[`demote`](../api_reference/then.md#demote) and [`promote`](../api_reference/else.md#promote) wrap these.

### Never-typed channels

A computation that can never end on a channel has that channel typed `Never`, for example one that can only fail. To widen it for composition, use `thenAbsurd` / `elseAbsurd`:

```dart
final Cont<(), String, Never> notFound = Cont.error('not found');
final Cont<(), String, int> widened = notFound.thenAbsurd<int>();
```

A `Never`-typed `Cont` can also be assigned to a wider type directly, because `Cont` is covariant in its error and value types:

```dart
final Cont<(), String, int> widened = notFound;
```

The opposite direction forgets information: `thenUnit` replaces the value with `()`, and `elseUnit` replaces the error with `()`, when only the fact of success or failure matters:

```dart
final Cont<(), String, ()> done = saveUser(user).thenUnit();
```

---

## Decorating

The `decorate` operator wraps the execution itself, letting you inject cross-cutting behavior like logging or scheduling without touching the value:

```dart
cont.decorate((run, env, observer) {
  print('Starting...');
  return run(env, observer);
});
```

---

## Next Steps

- **[Racing and Merging](04-racing-and-merging.md)** — Parallel composition and concurrency
- **[Environment Management](05-environment.md)** — Threading configuration through computations
