[Home](../../README.md) > User Guide

# Extending Jerelo

This guide shows you how to create custom computations, operators, and extensions that integrate seamlessly with Jerelo's composition model.

## Creating Custom Computations

The `Cont.fromRun` constructor gives you direct access to the environment and observer, allowing you to create computations with custom execution logic.

### Basic Anatomy

```dart
Cont<E, F, T> myComputation<E, F, T>() {
  return Cont.fromRun((env, observer) {
    // Your custom logic here
    final result = performWork();
    observer.onThen(result);
    // The canceller: what to do when the computation is cancelled.
    // Nothing to stop here, so it is a no-op.
    return () {};
  });
}
```

The run function receives the environment `env` and the observer, and must return a canceller of type `void Function()`. See [Cancellation](#cancellation) for what the canceller should do.

### The SafeObserver

The observer passed to `Cont.fromRun` is a `SafeObserver`, which provides:
- `observer.onThen(value)` — Signal success
- `observer.onElse(error)` — Signal a business-logic error
- `observer.onCrash(crash)` — Signal a crash
- `observer.isUsed()` — Returns `true` if any callback has already been invoked

Only this observer is guarded against duplicate calls; observers derived from it with `copyUpdate*` call their new callbacks every time. `fromRun` also catches only exceptions thrown synchronously by the run function. Such an exception is a crash, or a panic if the observer was already called; the outcome already reported stands. An exception thrown later inside a `Timer` or `Future` callback escapes to the zone, and the observer is never called. Wrap such callback bodies in `ContCrash.tryCatch`; if it returns a `CrashCrashOr`, pass its crash to `observer.onCrash`.

### Example: Delayed Computation

```dart
Cont<E, F, T> delay<E, F, T>(Duration duration, T value) {
  return Cont.fromRun((env, observer) {
    final timer = Timer(duration, () {
      observer.onThen(value);
    });
    // Cancelling stops the timer. Nothing is reported then;
    // see Cancellation below for reporting a cancel.
    return timer.cancel;
  });
}

// Usage
delay(Duration(seconds: 2), 42).run(
  (),
  onThen: (value) => print("Got $value after 2 seconds"),
);
```

### Example: Wrapping Callback-Based APIs

```dart
Cont<E, String, String> readFile<E>(String path) {
  return Cont.fromRun((env, observer) {
    File(path).readAsString().then(
      (contents) => observer.onThen(contents),
      onError: (error, stackTrace) {
        observer.onElse('Failed to read file: $error');
      },
    );
    // A Future cannot be stopped, so cancelling does nothing
    return () {};
  });
}
```

---

## Creating Custom Operators

You can create custom operators by combining existing Jerelo operators or by using `decorate` for lower-level control.

### Approach 1: Compose Existing Operators

Most custom operators can be built by composing existing ones:

```dart
extension MyContExtensions<E, F, T> on Cont<E, F, T> {
  // Retry a computation up to maxAttempts times on failure.
  // elseWhile loops without growing the stack, so even many
  // synchronous failures are safe. Fails with the last error.
  // fromDeferred gives each run its own attempt counter.
  Cont<E, F, T> retry(int maxAttempts) {
    return Cont.fromDeferred(() {
      var attempt = 1;
      return elseWhile((_) => attempt++ < maxAttempts);
    });
  }

  // Succeed with defaultValue if this hasn't succeeded within duration
  Cont<E, F3, T> timeout<F2, F3>(
    Duration duration,
    T defaultValue,
    F3 Function(F, F2) combineErrors,
  ) {
    final timeoutCont = delay<E, F2, T>(duration, defaultValue);

    return Cont.either(
      this,
      timeoutCont,
      combineErrors,
      policy: OkPolicy.quitFast(),
    );
  }

  // Log value for debugging without changing it
  Cont<E, F, T> debug(String label) {
    return thenMap((value) {
      print("[$label] $value");
      return value;
    });
  }
}
```

`timeout` builds on `either`, which waits on the else channel: a success or a crash ends the race immediately, but a failure waits for the other side. So if `this` fails before `duration` elapses, its error waits for the timer and the result is `defaultValue`. If fast failures must win, lift them to the then channel before racing, as shown in [Race with Timeout](04-racing-and-merging.md#race-with-timeout).

### Approach 2: Use `decorate` for Low-Level Control

The `decorate` method is a natural transformation that wraps the execution of a continuation without changing its type. It gives you access to three things:

- **`run`** — Runs the original computation, like `runWith` does
- **`env`** — The environment
- **`observer`** — The observer receiving the three outcome callbacks

You can intercept execution by modifying the environment or observer before passing them to `run`. `run` returns the canceller of the computation it starts; return it from your callback so that a cancel still reaches the computation. Don't throw after calling `run`: the throw becomes a crash (or a panic, if the computation has already reported), but the computation keeps running and can no longer be cancelled. `ContObserver` provides `copyUpdateOnThen`, `copyUpdateOnElse`, `copyUpdateOnCrash` and `copyUpdate` to derive new observers with selectively overridden callbacks. `copyUpdateOnThen` and `copyUpdateOnElse` are generic in the new value or error type; pass it explicitly (as below) when chaining them, because Dart cannot infer it there.

`decorate` preserves the continuation's type signature (`Cont<E, F, A>` → `Cont<E, F, A>`). It is not meant for type-changing transformations — use `thenMap`, `thenDo`, etc. for those.

**Example: Execution timing**

```dart
extension TimingExtension<E, F, T> on Cont<E, F, T> {
  Cont<E, F, T> timed(void Function(Duration elapsed) onDuration) {
    return decorate((run, env, observer) {
      final stopwatch = Stopwatch()..start();

      return run(
        env,
        observer
          .copyUpdateOnThen<T>((value) {
            stopwatch.stop();
            onDuration(stopwatch.elapsed);
            observer.onThen(value);
          })
          .copyUpdateOnElse<F>((error) {
            stopwatch.stop();
            observer.onElse(error);
          }),
      );
    });
  }
}

// Usage
fetchData()
  .timed((d) => print("Took ${d.inMilliseconds}ms"))
  .run((), onThen: print);
```

**Example: Conditional execution**

```dart
extension ConditionalExtension<E, F, A> on Cont<E, F, A> {
  Cont<E, F, A> onlyWhen(bool Function(E env) predicate, {required F fallback}) {
    return decorate((run, env, observer) {
      if (predicate(env)) {
        return run(env, observer);
      } else {
        observer.onElse(fallback);
        return () {};
      }
    });
  }
}

// Usage: only run in production
fetchAnalytics()
  .onlyWhen((env) => env.isProduction, fallback: 'skipped')
  .run(config, onThen: print);
```

**Example: Logging middleware**

```dart
extension LoggingExtension<E, F, T> on Cont<E, F, T> {
  Cont<E, F, T> logged(String label) {
    return decorate((run, env, observer) {
      print('[$label] Starting');
      return run(
        env,
        observer
          .copyUpdateOnThen<T>((value) {
            print('[$label] Success: $value');
            observer.onThen(value);
          })
          .copyUpdateOnElse<F>((error) {
            print('[$label] Error: $error');
            observer.onElse(error);
          })
          .copyUpdateOnCrash((crash) {
            print('[$label] Crash: $crash');
            observer.onCrash(crash);
          }),
      );
    });
  }
}
```

### Approach 3: Build on Your Own Operators

```dart
extension AdvancedExtensions<E, T> on Cont<E, String, T> {
  // Retry with exponential backoff. Fails with the last error, like retry.
  Cont<E, String, T> retryWithBackoff({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
  }) {
    Cont<E, String, T> attempt(int attemptsLeft, Duration currentDelay) {
      if (attemptsLeft <= 1) return this;

      return this.elseDo((_) {
        return delay<E, String, void>(currentDelay, null)
          .thenDo((_) => attempt(
            attemptsLeft - 1,
            currentDelay * 2,
          ));
      });
    }

    return attempt(maxAttempts, initialDelay);
  }
}
```

---

## Using the Environment

The `env` parameter passed to `Cont.fromRun` and `decorate` is the environment the computation runs with. To run an inner computation with a different environment, pass that environment to `runWith` (or to `run` inside `decorate`), and return the canceller it gives back:

```dart
Cont<E2, F, A> runIn<E, E2, F, A>(
  Cont<E, F, A> cont,
  E Function(E2 outer) f,
) {
  return Cont.fromRun((env, observer) {
    return cont.runWith(f(env), observer);
  });
}
```

This is exactly what `local` does; `local`, `local0` and `withEnv` cover this pattern, see [Environment](05-environment.md).

---

## Cancellation

`run` returns a `ContCancelToken`, and calling `cancel()` on it cancels the computation. Jerelo's operators never stop anything themselves: they only **forward** the cancel to the part that is running and to any part started afterwards. The computations you build with `Cont.fromRun` — the leaves — decide what cancelling means and how to report it.

### Writing a cancellable leaf

The canceller returned from `fromRun` runs when the computation is cancelled. It should stop the work and report the outcome through one of the existing channels — usually `onElse`, with an error type of your own:

```dart
final class Cancelled {
  const Cancelled();
}

Cont<E, Cancelled, T> cancellableDelay<E, T>(Duration duration, T value) {
  return Cont.fromRun((env, observer) {
    final timer = Timer(duration, () {
      observer.onThen(value);
    });
    return () {
      timer.cancel();
      observer.onElse(const Cancelled());
    };
  });
}

// Usage
final token = cancellableDelay<(), int>(const Duration(seconds: 5), 42).run(
  (),
  onElse: (_) => print('Cancelled'),
  onThen: (value) => print('Got $value'),
);

token.cancel(); // prints: Cancelled
```

Rules the library guarantees for a leaf's canceller:

- It runs **at most once**, and **never after** the leaf has reported an outcome. You do not need to guard against the timer having already fired.
- If it throws, the leaf crashes with that exception. If the leaf has already finished, the throw becomes a panic.
- A leaf that cannot be cancelled returns a no-op `() {}`. When cancelled, it simply finishes normally.
- A canceller that stops the work without reporting (like `return timer.cancel;`) leaves the computation without an outcome. That is fine for a loser of a `quitFast` race, whose result is ignored anyway, but `run`'s callbacks never hear from it and a `Cont.bracket` around it never releases.

When the underlying work cannot be stopped, such as a `Future`, the canceller can still report early — for example `return () => observer.onElse(const Cancelled());` — so the computation ends immediately; the result that arrives later is ignored by the `SafeObserver`.

### How operators forward a cancel

- Sequential operators (`thenDo`, `elseDo`, `thenTap`, …) forward a cancel to the stage that is running. If that stage still reports a value after the cancel, the next stage starts and is cancelled immediately.
- Combinators forward a cancel to every running branch. With a `quitFast` policy, once the result is decided, the losing branches are cancelled, and branches not started yet are never started. `runAll` never cancels on its own; `sequence` cancels the running item and every later item as it starts.
- Loops (the `*While` and `*Until` operators) forward a cancel to the running iteration and start no iteration after it; the loop ends with that iteration's outcome.
- `Cont.bracket` forwards a cancel to `use` only; `acquire` and `release` are never cancelled, and `release` runs once `use` reports back.
- Forks (`thenFork`, `elseFork`, `crashFork` and their variants) detach their side effect: it is not cancelled with the parent. The main computation is.
- In `decorate`, return what `run` returned so that the cancel keeps flowing.

### Limitations

Cancellation is only as good as the leaves. A leaf that ignores cancellation runs until it finishes, and your own code — for example the function passed to `thenDo` — can still run after a cancel when a stage reports a value after it. Write leaves that report a cancel promptly when you need computations to stop. See [Cancellation](../api_reference/execution.md#cancellation) for the full reference.

---

## Complete Custom Operator Example

Here's a comprehensive example combining multiple concepts:

```dart
extension RobustOperations<E, T> on Cont<E, String, T> {
  /// Retry with exponential backoff and logging
  Cont<E, String, T> robustFetch({
    int maxRetries = 3,
    Duration initialBackoff = const Duration(milliseconds: 100),
  }) {
    return this
      .retryWithBackoff(
        maxAttempts: maxRetries,
        initialDelay: initialBackoff,
      )
      .decorate((run, env, observer) {
        // Add logging and timing via decorate
        print('[robustFetch] Starting operation...');
        final stopwatch = Stopwatch()..start();

        return run(
          env,
          observer
            .copyUpdateOnThen<T>((result) {
              stopwatch.stop();
              print('[robustFetch] Completed in ${stopwatch.elapsedMilliseconds}ms');
              observer.onThen(result);
            })
            .copyUpdateOnElse<String>((error) {
              stopwatch.stop();
              print('[robustFetch] Failed after ${stopwatch.elapsedMilliseconds}ms: $error');
              observer.onElse(error);
            }),
        );
      });
  }
}

// Usage
fetchUserData(userId)
  .robustFetch(maxRetries: 5)
  .run(
    config,
    onThen: (user) => print('Success: $user'),
    onElse: (error) => print('Failed: $error'),
  );
```

---

## Next Steps

Now that you understand how to extend Jerelo, see:
- **[Complete Examples](07-examples.md)** - Real-world patterns and use cases
