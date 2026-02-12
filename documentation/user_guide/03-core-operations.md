[Home](../../README.md) > User Guide

# Core Operations: Transform, Chain & Branch

This guide covers the essential operations for building computation workflows.

## 3. Transform: Modifying Values

### Mapping

To transform a value inside `Cont`, use `thenMap`:

```dart
Cont.of(0).thenMap((zero) {
  return zero + 1;
}).run((), onThen: print); // prints 1
```

**Variants:**
- `thenMap(f)` - Transform value with function
- `thenMap0(f)` - Transform with zero-argument function (ignores current value)
- `thenMapWithEnv(f)` - Transform with access to environment and value
- `thenMapWithEnv0(f)` - Transform with access to environment only
- `thenMapTo(value)` - Replace value with a constant

### Hoisting

Sometimes you need to intercept or modify how a continuation executes, without changing the value it produces. The `decor` operator lets you wrap the underlying run function with custom behavior.

This is useful for:
- Logging when execution starts
- Adding timing/profiling
- Wrapping with try-catch for additional error handling
- Scheduling
- Modifying observer behavior

```dart
// `delay` is not a real operator. It is a contrived example.
final cont = Cont.of(42).delay(Duration(milliseconds: 2));

// Add logging around execution
final logged = cont.decor((run, runtime, observer) {
  print('Execution starting...');
  run(runtime, observer);
  print('Execution initiated');
});

logged.run((), onThen: print);
// Prints:
// Execution starting...
// Execution initiated
// 42
```

**Note:** `decor` is a natural transformation that gives you full control over the execution mechanics, making it the most powerful operator for creating custom behaviors.

---

## 4. Chain: Sequencing Computations

Chaining is constructing a computation from the result of the previous one. This is the heart of composing computations.

Jerelo provides two families of chaining operators:
- **Success operators** (`then*`): Continue the chain when computation succeeds
- **Error operators** (`else*`): Handle termination and provide fallbacks

### Success Chaining

Use `thenDo` to chain computations based on success values:

```dart
Cont.of(0).thenDo((zero) {
  return Cont.of(zero + 1);
}).run((), onThen: print); // prints 1
```

Other success operators include:
- `thenTap`: Execute side effects while passing the original value through
- `thenZip`: Combine the original value with a new computation's result
- `thenFork`: Run a computation in the background without blocking the chain (fire-and-forget)

**Variants:** All success operators have `0`, `WithEnv`, and `WithEnv0` variants (e.g., `thenDo0`, `thenDoWithEnv`, `thenDoWithEnv0`)

Here's how chaining makes composition clean:

```dart
final program = function1(value)
  .thenDo(function2)
  .thenDo((result2) {
    // the rest of the program
  });
```

This is a dramatic improvement over the nested callback style!

### Error Chaining

Use `elseDo` to recover from termination by providing a fallback:

```dart
Cont.stop<(), int>([ContError.capture("fail")])
  .elseDo((errors) {
    print("Caught: ${errors[0].error}");
    return Cont.of(42); // recover with default value
  })
  .run((), onThen: print); // prints: Caught: fail, then: 42
```

**Variants:** `elseDo0`, `elseDoWithEnv`, `elseDoWithEnv0`

### Error Transformation with elseMap

The `elseMap` operator transforms the error list on the termination channel without changing the channel (stays on termination). This is useful for adding context, filtering errors, or wrapping errors in a different format.

```dart
Cont.stop<(), int>([ContError.capture("connection timeout")])
  .elseMap((errors) {
    return errors.map((e) =>
      ContError.capture("Network error: ${e.error}")
    ).toList();
  })
  .run(
    (),
    onElse: (errors) => print(errors.first.error),
  ); // prints "Network error: connection timeout"
```

**Difference from `elseDo`:**
- `elseMap`: Transforms errors and stays on termination channel (returns `List<ContError>`)
- `elseDo`: Can recover to success channel (returns `Cont<E, A>`)

**Variants:** `elseMap0`, `elseMapWithEnv`, `elseMapWithEnv0`, `elseMapTo`

### Other Error Operators

- `elseTap`: Execute side effects on termination (e.g., logging) while preserving the original errors
- `elseZip`: Runs fallback and combines errors from both attempts
- `elseFork`: Handle errors in the background without blocking (fire-and-forget)
- `recover`: Compute a replacement value from the errors (convenience shorthand for `elseDo`)
- `recover0`: Compute a replacement value ignoring the errors
- `recoverWith`: Provide a constant fallback value on termination

**Variants:** All error operators have `0`, `WithEnv`, and `WithEnv0` variants

### Environment Variants

All chaining operators have `WithEnv` variants that provide access to the environment parameter. These are explained in detail in the [Environment Management](05-environment.md) guide.

```dart
Cont.of(42).thenDoWithEnv((env, value) {
  return fetchWithConfig(env.apiUrl, value);
});

computation.elseDoWithEnv((env, errors) {
  return loadFromCache(env.cacheDir);
});
```

---

## 5. Branch: Conditional Logic

Branching operators allow you to conditionally execute or repeat computations based on predicates.

### Conditional Execution

The `thenIf` operator filters a computation based on a predicate. If the predicate returns `true`, the computation succeeds with the value. If it returns `false`, the computation terminates without errors.

```dart
Cont.of(5)
  .thenIf((value) => value > 3)
  .run(
    (),
    onElse: (_) => print("terminated"),
    onThen: (value) => print("success: $value"),
  ); // prints "success: 5"

Cont.of(2)
  .thenIf((value) => value > 3)
  .run(
    (),
    onElse: (_) => print("terminated"),
    onThen: (value) => print("success: $value"),
  ); // prints "terminated"
```

This is useful for early termination of computation chains when certain conditions are not met.

**Variants:** `thenIf0`, `thenIfWithEnv`, `thenIfWithEnv0`

#### Conditional Recovery with elseIf

The `elseIf` operator is the error-channel counterpart to `thenIf`. While `thenIf` filters values on the success channel, `elseIf` filters errors on the termination channel and provides conditional recovery.

If the predicate returns `true`, the computation recovers with the provided value. If the predicate returns `false`, the computation continues terminating with the original errors.

```dart
Cont.stop<(), int>([ContError.capture('not found')])
  .elseIf((errors) => errors.first.error == 'not found', 42)
  .run(
    (),
    onElse: (_) => print("terminated"),
    onThen: (value) => print("success: $value"),
  ); // prints "success: 42"

Cont.stop<(), int>([ContError.capture('fatal error')])
  .elseIf((errors) => errors.first.error == 'not found', 42)
  .run(
    (),
    onElse: (errors) => print("terminated: ${errors.first.error}"),
    onThen: (value) => print("success: $value"),
  ); // prints "terminated: fatal error"
```

**Variants:** `elseIf0`, `elseIfWithEnv`, `elseIfWithEnv0`

This is particularly useful for:
- Recovering from specific error types while propagating others
- Implementing fallback values based on error conditions
- Creating error-handling strategies that depend on the error context

**Real-world example: Handling network errors with fallbacks**

```dart
fetchUserFromNetwork(userId)
  .elseIf(
    (errors) => errors.any((e) => e.error.toString().contains('404')),
    User.guest(), // Use guest user if not found
  )
  .elseIf(
    (errors) => errors.any((e) => e.error.toString().contains('timeout')),
    User.cached(userId), // Use cached user on timeout
  )
  .elseDo((errors) {
    // All other errors propagate
    return Cont.stop(errors);
  })
  .run(
    (),
    onElse: (errors) => print("Failed to get user: $errors"),
    onThen: (user) => print("Got user: ${user.name}"),
  );
```

#### Branching with thenIf-thenDo-elseDo

While `thenIf` is powerful on its own, combining it with `thenDo` and `elseDo` creates an elegant if-then-else pattern that's fully composable. Since `thenIf` terminates when the predicate is false, you can use `elseDo` to recover from that termination and provide an alternative path:

```dart
Cont.of(5)
  .thenIf((value) => value > 3)
  .thenDo((value) {
    // Handle the "if true" branch
    return Cont.of("Value $value is greater than 3");
  })
  .elseDo((errors) {
    // Handle the "if false" branch
    return Cont.of("Value was not greater than 3");
  })
  .run((), onThen: print); // prints "Value 5 is greater than 3"

Cont.of(2)
  .thenIf((value) => value > 3)
  .thenDo((value) {
    // This won't execute because predicate is false
    return Cont.of("Value $value is greater than 3");
  })
  .elseDo((errors) {
    // This executes as a fallback
    return Cont.of("Value was not greater than 3");
  })
  .run((), onThen: print); // prints "Value was not greater than 3"
```

This pattern is particularly handy because:
- **Composable**: Both branches return `Cont`, so they can be further chained
- **Type-safe**: The result type is consistent across both branches
- **Readable**: Clearly expresses conditional logic without nesting
- **Integrated**: Fits naturally into longer computation chains

```dart
// Real-world example: validate user age and take different actions
getUserAge(userId)
  .thenIf((age) => age >= 18)
  .thenDo((age) => grantFullAccess(userId))
  .elseDo((_) => grantRestrictedAccess(userId))
  .thenDo((accessLevel) => logAccessGrant(userId, accessLevel))
  .run(
    (),
    onElse: (errors) => print("Failed to process user: $errors"),
    onThen: (result) => print("Access granted: $result"),
  );
```

### Forced Termination with abort

The `abort` operator unconditionally switches to the termination channel with computed errors, regardless of whether the computation succeeded or failed. This is useful when you need to forcefully terminate based on the result value.

```dart
Cont.of(42)
  .abort((value) => [ContError.capture("Value $value is not allowed")])
  .run(
    (),
    onElse: (errors) => print("Terminated: ${errors.first.error}"),
    onThen: (value) => print("Success: $value"),
  ); // prints "Terminated: Value 42 is not allowed"
```

The key difference from `thenIf` is that `abort` computes the error list dynamically from the value, while `thenIf` simply filters without producing custom errors.

**Variants:**
- `abort(f)` - Compute errors from value
- `abort0(f)` - Compute errors without examining value
- `abortWithEnv(f)` - Compute errors with environment access
- `abortWithEnv0(f)` - Compute errors from environment only
- `abortWith(errors)` - Unconditionally terminate with fixed error list

**Example: Validation with custom error messages**

```dart
getUserInput()
  .abortWith([ContError.capture("Input required")])
    .thenIf((input) => input.isNotEmpty)
  .abort((input) {
    if (input.length < 3) {
      return [ContError.capture("Input too short: minimum 3 characters")];
    }
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(input)) {
      return [ContError.capture("Input must contain only letters")];
    }
    return []; // Won't actually abort if empty list
  })
  .thenDo((validInput) => processInput(validInput))
  .run(
    (),
    onElse: (errors) => print("Validation failed: ${errors.first.error}"),
    onThen: (result) => print("Processed: $result"),
  );
```

### Looping with thenWhile

The `thenWhile` operator repeatedly executes a computation as long as the predicate returns `true`. The loop stops when the predicate returns `false`, and the computation succeeds with that final value.

```dart
// Retry getting a value until it's greater than 5
Cont.of(0)
  .thenMap((n) => Random().nextInt(10)) // generate random 0..9
  .thenWhile((value) => value <= 5)
  .run((), onThen: (value) {
    print("Got value > 5: $value");
  });
```

The loop is stack-safe and handles asynchronous continuations correctly. If the continuation terminates or the predicate throws, the loop stops and propagates the errors.

Ideal for:
- Retry logic with conditions
- Polling until a state changes
- Repeating operations while a condition holds

**Variants:** `thenWhile0`, `thenWhileWithEnv`, `thenWhileWithEnv0`

### Looping with thenUntil

If you want to loop until a condition is met (inverted logic), use `thenUntil`:

```dart
// Retry getting a value until it's greater than 5
Cont.of(0)
  .thenMap((n) => Random().nextInt(10)) // generate random 0..9
  .thenUntil((value) => value > 5) // inverted condition
  .run((), onThen: (value) {
    print("Got value > 5: $value");
  });
```

**Variants:** `thenUntil0`, `thenUntilWithEnv`, `thenUntilWithEnv0`

### Looping forever

Use `forever` to create an infinite loop that never terminates normally:

```dart
Cont.of(())
  .thenTap((_) => checkForMessages())
  .thenTap((_) => delay(Duration(seconds: 1)))
  .forever()
  .run((), onElse: (errors) {
    print("Loop terminated: $errors");
  });
```

The `forever` operator returns `Cont<E, Never>`, indicating it never produces a value on the success channel. It can only terminate through errors or cancellation.

### Working with Never-Producing Continuations

Some operations produce `Cont<E, Never>`, meaning they can only terminate through errors, never through success. Jerelo provides special extensions for working with these:

#### trap: Execute Termination-Only Continuation

The `trap` method executes a `Cont<E, Never>` when you only care about errors:

```dart
final neverSucceeds = Cont.of(())
  .thenDo((_) => Cont.stop([ContError.capture("always fails")]))
  .forever();

// Only provide error handler - no onThen needed
final token = neverSucceeds.trap(
  (),
  onElse: (errors) => print("Terminated: ${errors.first.error}"),
);
```

Since `Cont<E, Never>` can never succeed, `trap` doesn't require an `onThen` callback, making your intent clearer.

#### absurd: Convert Never to Any Type

The `absurd` method converts a `Cont<E, Never>` to any result type. This is safe because the continuation can never actually produce a value:

```dart
final Cont<(), Never> neverProduces = loopForever();

// Convert to any type you need
final Cont<(), String> asString = neverProduces.absurd<String>();
final Cont<(), int> asInt = neverProduces.absurd<int>();

// This is safe because if neverProduces actually terminates,
// it will be through the error channel, not by producing a value
```

**Use cases for Never-producing continuations:**
- Long-running services that should never exit normally
- Event loops that only terminate on errors
- Infinite retry mechanisms
- Daemon processes
- WebSocket listeners

### Error Retry Loops with elseWhile and elseUntil

Just as `thenWhile` and `thenUntil` loop on the success channel, `elseWhile` and `elseUntil` provide retry logic on the error channel.

#### elseWhile: Retry while predicate is true

The `elseWhile` operator retries a computation as long as the error predicate returns `true`:

```dart
// Retry while getting network timeouts, up to 3 times
int attempts = 0;
fetchFromApi()
  .elseWhile((errors) {
    attempts++;
    final isTimeout = errors.any((e) => e.error.toString().contains('timeout'));
    return isTimeout && attempts < 3;
  })
  .run(
    (),
    onElse: (errors) => print("Failed after retries: ${errors.first.error}"),
    onThen: (data) => print("Success: $data"),
  );
```

**Variants:** `elseWhile0`, `elseWhileWithEnv`, `elseWhileWithEnv0`

#### elseUntil: Retry until predicate is true

The `elseUntil` operator retries until the error predicate returns `true` (inverted logic):

```dart
// Retry until we get a non-retryable error or succeed
fetchFromApi()
  .elseUntil((errors) {
    // Stop retrying if error is not retryable
    return errors.any((e) => e.error.toString().contains('unauthorized'));
  })
  .run(
    (),
    onElse: (errors) => print("Stopped retrying: ${errors.first.error}"),
    onThen: (data) => print("Success: $data"),
  );
```

**Variants:** `elseUntil0`, `elseUntilWithEnv`, `elseUntilWithEnv0`

**Common use cases:**
- Retry with exponential backoff (combine with `delay`)
- Retry on transient errors (network timeouts, rate limits)
- Circuit breaker patterns
- Polling until success or non-retryable error

---

## Next Steps

Now that you understand the core operations, continue to:
- **[Advanced Operations](04-advanced-operations.md)** - Learn to merge computations and handle concurrency
- **[Environment Management](05-environment.md)** - Master environment handling
- **[Complete Examples](07-examples.md)** - See real-world patterns
- **[API Reference](../api_reference/)** - Quick reference lookup
