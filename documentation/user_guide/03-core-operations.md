[Home](../../README.md) > User Guide

# Core Operations: Transform, Chain & Branch

This guide covers the essential operations for building computation workflows.

## 3. Transform: Modifying Values

### Mapping

To transform a value inside `Cont`, use `thenMap`:

```dart
Cont.of(0).thenMap((zero) {
  return zero + 1;
}).run(null, onThen: print); // prints 1
```

**Variants:**
- `thenMap(f)` - Transform value with function
- `thenMap0(f)` - Transform with zero-argument function (ignores current value)
- `thenMapWithEnv(f)` - Transform with access to environment and value
- `thenMapWithEnv0(f)` - Transform with access to environment only
- `thenMapTo(value)` - Replace value with a constant

### Decorating

Sometimes you need to intercept or modify how a continuation executes, without changing the value it produces. The `decorate` operator lets you wrap the underlying run function with custom behavior.

This is useful for:
- Logging when execution starts
- Adding timing/profiling
- Scheduling
- Modifying observer behavior

```dart
final cont = Cont.of(42);

// Add logging around execution
final logged = cont.decorate((run, runtime, observer) {
  print('Execution starting...');
  run(runtime, observer);
  print('Execution initiated');
});

logged.run(null, onThen: print);
// Prints:
// Execution starting...
// Execution initiated
// 42
```

**Note:** `decorate` is a natural transformation that gives you full control over the execution mechanics, making it the most powerful operator for creating custom behaviors.

---

## 4. Chain: Sequencing Computations

Chaining is constructing a computation from the result of the previous one. This is the heart of composing computations.

Jerelo provides three families of chaining operators:
- **Then operators** (`then*`): Continue the chain when computation succeeds
- **Else operators** (`else*`): Handle typed business-logic errors
- **Crash operators** (`crash*`): Handle unexpected exceptions

### Success Chaining

Use `thenDo` to chain computations based on success values:

```dart
Cont.of(0).thenDo((zero) {
  return Cont.of(zero + 1);
}).run(null, onThen: print); // prints 1
```

Other success operators include:
- `thenTap`: Execute side effects while preserving the original value
- `thenZip`: Combine the original value with a new computation's result
- `thenFork`: Run a computation in the background without blocking the chain (fire-and-forget). Accepts optional `onPanic`, `onCrash`, `onElse`, and `onThen` callbacks to observe outcomes of the forked continuation

**Variants:** All success operators have `0`, `WithEnv`, and `WithEnv0` variants (e.g., `thenDo0`, `thenDoWithEnv`, `thenDoWithEnv0`)

Here's how chaining makes composition clean:

```dart
final program = function1(value)
  .thenDo(function2)
  .thenDo((result2) {
    // the rest of the program
  });
```

### Error Chaining

Use `elseDo` to recover from a business-logic error by providing a fallback:

```dart
Cont.error<void, String, int>('not found')
  .elseDo((error) {
    print("Caught: $error");
    return Cont.of(42); // recover with default value
  })
  .run(null, onThen: print); // prints: Caught: not found, then: 42
```

**Variants:** `elseDo0`, `elseDoWithEnv`, `elseDoWithEnv0`

### Error Transformation with elseMap

The `elseMap` operator transforms the error on the else channel without changing the channel (stays on else). This is useful for adding context, adapting error types, or wrapping errors in a different format.

```dart
Cont.error<void, String, int>('connection timeout')
  .elseMap((error) {
    return 'Network error: $error';
  })
  .run(
    null,
    onElse: (error) => print(error),
  ); // prints "Network error: connection timeout"
```

**Difference from `elseDo`:**
- `elseMap`: Transforms the error and stays on else channel (returns a new error of type `F2`)
- `elseDo`: Can recover to success channel (returns `Cont<E, F2, A>`)

**Variants:** `elseMap0`, `elseMapWithEnv`, `elseMapWithEnv0`, `elseMapTo`

### Crash Chaining

Use `crashDo` to recover from unexpected exceptions:

```dart
Cont.fromRun<void, String, int>((runtime, observer) {
  throw 'something unexpected';
}).crashDo((crash) {
  print('Recovered from crash: $crash');
  return Cont.of(0); // recover with default
}).run(null, onThen: print); // prints 0
```

**Variants:** `crashDo0`, `crashDoWithEnv`, `crashDoWithEnv0`

### Other Error Operators

- `elseTap`: Execute side effects on error while preserving the original error
- `elseZip`: Run fallback and combine errors from both attempts
- `elseFork`: Handle errors in the background without blocking (fire-and-forget). Accepts optional observation callbacks for the forked continuation's outcomes
- `promote`: Compute a replacement value from the error (convenience over `elseDo`)
- `promote0`: Compute a replacement value ignoring the error
- `promoteWith`: Provide a constant fallback value on error
- `promoteWithEnv`, `promoteWithEnv0`: Variants with environment access

### Other Crash Operators

- `crashTap`: Execute side effects on crash
- `crashZip`: Run recovery and combine crashes from both attempts
- `crashFork`: Handle crashes in the background without blocking. Accepts optional observation callbacks for the forked continuation's outcomes
- `crashRecoverThen`: Compute a success value from the crash
- `crashRecoverThenWith`: Provide a constant fallback on crash
- `crashRecoverElse`: Compute a typed error from the crash
- `crashRecoverElseWith`: Provide a constant error on crash

### Environment Variants

All chaining operators have `WithEnv` variants that provide access to the environment parameter. These are explained in detail in the [Environment Management](05-environment.md) guide.

```dart
Cont.of(42).thenDoWithEnv((env, value) {
  return fetchWithConfig(env.apiUrl, value);
});

computation.elseDoWithEnv((env, error) {
  return loadFromCache(env.cacheDir);
});
```

---

## 5. Branch: Conditional Logic

Branching operators allow you to conditionally execute or repeat computations based on predicates.

### Conditional Execution with thenIf

The `thenIf` operator filters a computation based on a predicate. If the predicate returns `true`, the computation succeeds with the value. If it returns `false`, the computation terminates on the else channel with the required `fallback` error.

```dart
Cont.of<void, String, int>(5)
  .thenIf((value) => value > 3, fallback: 'too small')
  .run(
    null,
    onElse: (error) => print("error: $error"),
    onThen: (value) => print("success: $value"),
  ); // prints "success: 5"

Cont.of<void, String, int>(2)
  .thenIf((value) => value > 3, fallback: 'too small')
  .run(
    null,
    onElse: (error) => print("error: $error"),
    onThen: (value) => print("success: $value"),
  ); // prints "error: too small"
```

**Variants:** `thenIf0`, `thenIfWithEnv`, `thenIfWithEnv0`

### Conditional Recovery with elseUnless

The `elseUnless` operator is the error-channel counterpart to `thenIf`. It conditionally promotes from error to success.

If the predicate returns `true`, the error is preserved. If the predicate returns `false`, the computation recovers with the provided `fallback` value.

```dart
Cont.error<void, String, int>('not found')
  .elseUnless((error) => error == 'not found', fallback: 42)
  .run(
    null,
    onElse: (error) => print("error: $error"),
    onThen: (value) => print("success: $value"),
  ); // prints "success: 42"

Cont.error<void, String, int>('fatal error')
  .elseUnless((error) => error == 'not found', fallback: 42)
  .run(
    null,
    onElse: (error) => print("error: $error"),
    onThen: (value) => print("success: $value"),
  ); // prints "error: fatal error"
```

**Variants:** `elseUnless0`, `elseUnlessWithEnv`, `elseUnlessWithEnv0`

This is particularly useful for:
- Recovering from specific error types while propagating others
- Implementing fallback values based on error conditions
- Creating error-handling strategies that depend on the error context

### Conditional Crash Recovery with crashUnless

The crash channel has its own conditional recovery operators:

- `crashUnlessThen`: If predicate is `false`, recover to a success value
- `crashUnlessElse`: If predicate is `false`, recover to a typed error

```dart
someCont
  .crashUnlessThen(
    (crash) => crash is NormalCrash && crash.error == 'fatal',
    fallback: 0,
  )
  .run(null, onThen: print);
```

**Variants:** `crashUnlessThen0`, `crashUnlessThenWithEnv`, `crashUnlessThenWithEnv0`, `crashUnlessElse0`, `crashUnlessElseWithEnv`, `crashUnlessElseWithEnv0`

### Branching with thenIf-thenDo-elseDo

While `thenIf` is powerful on its own, combining it with `thenDo` and `elseDo` creates an elegant if-then-else pattern that's fully composable. Since `thenIf` terminates on the else channel when the predicate is false, you can use `elseDo` to recover from that and provide an alternative path:

```dart
Cont.of<void, String, int>(5)
  .thenIf((value) => value > 3, fallback: 'not greater')
  .thenDo((value) {
    // Handle the "if true" branch
    return Cont.of("Value $value is greater than 3");
  })
  .elseDo((error) {
    // Handle the "if false" branch
    return Cont.of("Value was not greater than 3");
  })
  .run(null, onThen: print); // prints "Value 5 is greater than 3"
```

### Demoting to Error with demote

The `demote` operator unconditionally switches from the success channel to the else channel. It takes a value and converts it into a typed error.

```dart
Cont.of(42)
  .demote((value) => "Value $value is not allowed")
  .run(
    null,
    onElse: (error) => print("Error: $error"),
    onThen: (value) => print("Success: $value"),
  ); // prints "Error: Value 42 is not allowed"
```

**Variants:**
- `demote(f)` - Compute error from value
- `demote0(f)` - Compute error without examining value
- `demoteWithEnv(f)` - Compute error with environment access
- `demoteWithEnv0(f)` - Compute error from environment only
- `demoteWith(error)` - Unconditionally demote with fixed error

### Promoting to Success with promote

The `promote` operator is the inverse of `demote` — it converts a typed error into a success value:

```dart
Cont.error<void, String, int>('fallback needed')
  .promote((error) => 0)
  .run(null, onThen: print); // prints 0
```

**Variants:** `promote0`, `promoteWithEnv`, `promoteWithEnv0`, `promoteWith`

### Looping with thenWhile

The `thenWhile` operator repeatedly executes a computation as long as the predicate returns `true`. The loop stops when the predicate returns `false`, and the computation succeeds with that final value.

```dart
// Retry getting a value until it's greater than 5
Cont.of(0)
  .thenMap((n) => Random().nextInt(10)) // generate random 0..9
  .thenWhile((value) => value <= 5)
  .run(null, onThen: (value) {
    print("Got value > 5: $value");
  });
```

The loop is stack-safe and handles asynchronous continuations correctly. If the continuation crashes or the predicate throws, the loop stops.

### Looping with thenUntil

If you want to loop until a condition is met (inverted logic), use `thenUntil`:

```dart
Cont.of(0)
  .thenMap((n) => Random().nextInt(10))
  .thenUntil((value) => value > 5) // inverted condition
  .run(null, onThen: (value) {
    print("Got value > 5: $value");
  });
```

### Looping forever

Use `thenForever` to create an infinite loop that never succeeds normally:

```dart
Cont.of(())
  .thenTap((_) => checkForMessages())
  .thenForever()
  .run(null, onElse: (error) {
    print("Loop terminated with error: $error");
  });
```

The `thenForever` operator returns `Cont<E, F, Never>`, indicating it never produces a value on the success channel. It can only terminate through errors, crashes, or cancellation.

### Error Retry Loops with elseWhile and elseUntil

Just as `thenWhile` and `thenUntil` loop on the success channel, `elseWhile` and `elseUntil` provide retry logic on the error channel.

#### elseWhile: Retry while predicate is true

```dart
fetchFromApi()
  .elseWhile((error) {
    return error == 'timeout';
  })
  .run(
    null,
    onElse: (error) => print("Failed: $error"),
    onThen: (data) => print("Success: $data"),
  );
```

#### elseUntil: Retry until predicate is true

```dart
fetchFromApi()
  .elseUntil((error) {
    return error == 'unauthorized'; // stop retrying on auth errors
  })
  .run(
    null,
    onElse: (error) => print("Stopped retrying: $error"),
    onThen: (data) => print("Success: $data"),
  );
```

#### elseForever: Retry indefinitely

```dart
// A connection that automatically reconnects forever
final connection = connectToServer()
    .elseForever();
```

### Crash Retry Loops

The crash channel has its own loop operators:
- `crashWhile`: Retry while crash predicate is true
- `crashUntil`: Retry until crash predicate is true
- `crashForever`: Retry indefinitely on crash

### Working with Never-Producing Continuations

Some operations produce `Cont<E, F, Never>` (e.g., `thenForever`), meaning they can only terminate through errors or crashes, never through success.

#### thenAbsurd: Convert Never success to any type

```dart
final Cont<void, String, Never> neverProduces = loopForever();

// Convert to any type you need
final Cont<void, String, String> asString = neverProduces.thenAbsurd<String>();
final Cont<void, String, int> asInt = neverProduces.thenAbsurd<int>();
```

#### elseAbsurd: Convert Never error to any type

When a continuation has `Never` as its error type (meaning it can never fail with a business-logic error):

```dart
final Cont<void, Never, int> neverFails = Cont.of(42);

// Widen to any error type
final Cont<void, String, int> withStringError = neverFails.elseAbsurd<String>();
```

#### absurdify: Widen both Never channels

```dart
final cont = someNeverCont.absurdify(); // widens both then and else if either is Never
```

---

## Next Steps

Now that you understand the core operations, continue to:
- **[Racing and Merging](04-racing-and-merging.md)** - Learn to merge computations and handle concurrency
- **[Environment Management](05-environment.md)** - Master environment handling
