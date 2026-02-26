[Home](../../README.md) > User Guide

# Composing Computations

Once you can construct and run a `Cont`, the next step is composing computations together. Every operator in Jerelo works on one of three channels — **then** (success), **else** (typed error), or **crash** (unexpected exception) — and most follow a consistent naming convention:

Most operators come in a family of variants: 
- the **base** form receives the channel value, 
- **`0`** ignores it, 
- **`WithEnv`** adds the environment, 
- **`WithEnv0`** receives only the environment, 
- and **`To`** / **`With`** replaces with a constant. 

For example: 
- `thenMap` 
- `thenMap0` 
- `thenMapWithEnv` 
- `thenMapWithEnv0` 
- `thenMapTo` 

all exist. The guide below shows the base form; the variants work identically.

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

Each channel also has **tap** (run a side-effect, keep the original value), **zip** (combine original with a second computation's result), and **fork** (fire-and-forget a background computation). So `thenTap`, `elseTap`, `crashTap`, `thenZip`, `elseZip`, `crashZip`, `thenFork`, `elseFork`, `crashFork` all exist — each with the standard variant suffixes.

### Crash Recovery

`crashRecoverThen` and `crashRecoverElse` convert a crash into a success value or a typed error directly, without wrapping it in a `Cont`:

```dart
someCont
  .crashRecoverThenWith(0) // crash → success with constant
  .run((), onThen: print);

someCont
  .crashRecoverElse((crash) => 'Unexpected: $crash') // crash → typed error
  .run((), onElse: print);
```

### Flattening

`flatten` collapses a nested `Cont<E, F, Cont<E, F, A>>` into `Cont<E, F, A>`:

```dart
nested.flatten().run((), onThen: print);
```

### Environment Variants

All chaining operators have `WithEnv` variants. See the [Environment Management](05-environment.md) guide for details.

---

## Conditionals

### thenIf / elseUnless

`thenIf` keeps the value when a predicate is `true`, otherwise diverts to the else channel with a `fallback` error. `elseUnless` is the mirror — it recovers from error to success when the predicate is `false`.

```dart
Cont.of<(), String, int>(5)
  .thenIf((n) => n > 3, fallback: 'too small')
  .run((), onThen: print); // prints 5

Cont.of<(), String, int>(2)
  .thenIf((n) => n > 3, fallback: 'too small')
  .run((), onElse: print); // prints "too small"
```

Combine them with chaining to build an if-then-else:

```dart
Cont.of<(), String, int>(5)
  .thenIf((n) => n > 3, fallback: 'not greater')
  .thenDo((n) => Cont.of("$n is big"))
  .elseDo((_) => Cont.of("too small"))
  .run((), onThen: print); // prints "5 is big"
```

The crash channel has `crashUnlessThen` and `crashUnlessElse` for conditional crash recovery.

---

## Loops

`thenWhile` repeats the computation as long as the predicate holds. `thenUntil` repeats until the predicate becomes true (inverted logic).

```dart
Cont.of(0)
  .thenMap((_) => Random().nextInt(10))
  .thenWhile((n) => n <= 5)
  .run((), onThen: print); // prints the first value > 5
```

`thenForever` loops indefinitely — it returns `Cont<E, F, Never>` and can only terminate through error, crash, or cancellation.

The same operators exist on the else and crash channels for retry logic: `elseWhile` / `elseUntil` / `elseForever` and `crashWhile` / `crashUntil` / `crashForever`. `elseForever` returns `Cont<E, Never, A>` (never errors). All loop operators have the standard variant suffixes.

---

## Switching Channels

### demote / promote

`demote` moves a success value to the else channel. `promote` does the reverse.

```dart
Cont.of(42)
  .demote((n) => "Value $n not allowed")
  .run((), onElse: print); // prints "Value 42 not allowed"

Cont.error<(), String, int>('fallback')
  .promote((_) => 0)
  .run((), onThen: print); // prints 0
```

Both have the full set of variant suffixes, including `demoteWith` / `promoteWith` for constant values.

### Never-typed channels

Operators like `thenForever` and `elseForever` produce a `Never`-typed channel. To widen it for composition, use `thenAbsurd` / `elseAbsurd`:

```dart
final Cont<(), String, Never> loop = server().thenForever();
final Cont<(), String, int> widened = loop.thenAbsurd<int>();
```

`absurdify` widens whichever channels are `Never` and is safe to call on any `Cont`.

---

## Decorating

The `decorate` operator wraps the execution itself, letting you inject cross-cutting behavior like logging or scheduling without touching the value:

```dart
cont.decorate((run, runtime, observer) {
  print('Starting...');
  run(runtime, observer);
});
```

---

## Next Steps

- **[Racing and Merging](04-racing-and-merging.md)** — Parallel composition and concurrency
- **[Environment Management](05-environment.md)** — Threading configuration through computations
