[Home](../../README.md) > User Guide

# Composing Computations

Once you can construct and run a `Cont`, the next step is composing computations together. Every operator in Jerelo works on one of three channels — **then** (success), **else** (typed error), or **crash** (unexpected exception).

Jerelo is built on a small set of fundamental operators: `thenMap`, `thenDo`, `elseMap`, `elseDo`, `crashDo`, `flatten`, `Cont.tailRecM` and `decorate`, plus the combinators and environment operators covered in the next guides. Everything else in this guide is built from them.

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

`Cont.tailRecM` is the core loop. It runs a step with a state; the step succeeds with `TailRec.next(state)` to run again with a new state, or with `TailRec.done(result)` to finish. If a step ends on the else or crash channel, the loop ends with that outcome. The loop is stack-safe, so it can run any number of iterations, even when the steps complete synchronously.

```dart
final Cont<(), Never, int> firstBig = Cont.tailRecM((), (_) {
  return Cont.of<(), Never, ()>(())
    .thenMap((_) => Random().nextInt(10))
    .thenMap((n) => n > 5 ? TailRec.done(n) : TailRec.next(()));
});

firstBig.run((), onThen: print); // prints the first value > 5
```

Give the result a type, as above, or pass the type arguments to `Cont.tailRecM`: Dart cannot infer the result type from a `TailRec.done(...)` inside the step.

Retries follow the same shape: the state is the attempt number, success finishes the loop, and an error continues it until the attempts run out.

```dart
Cont<(), String, Data> fetchWithRetry(int maxAttempts) {
  return Cont.tailRecM(1, (int attempt) {
    return fetchData()
      .thenMap<TailRec<int, Data>>(TailRec.done)
      .elseDo((error) {
        return attempt < maxAttempts
          ? Cont.of(TailRec.next(attempt + 1))
          : Cont.error(error);
      });
  });
}
```

The `while`/`until`/`forever` loops on every channel (`thenWhile`, `elseUntil`, `crashForever`, …) are built on `Cont.tailRecM`; see the [then](../api_reference/then.md#loops), [else](../api_reference/else.md#retry-loops) and [crash](../api_reference/crash.md#retry-loops) loops.

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

A loop that never finishes produces a `Never`-typed channel. To widen it for composition, use `thenAbsurd` / `elseAbsurd`:

```dart
final Cont<(), String, Never> loop = Cont.tailRecM(
  (),
  (_) => server().thenMap((_) => TailRec.next(())),
);
final Cont<(), String, int> widened = loop.thenAbsurd<int>();
```

A `Never`-typed `Cont` can also be assigned to a wider type directly, because `Cont` is covariant in its error and value types:

```dart
final Cont<(), String, int> widened = loop;
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
