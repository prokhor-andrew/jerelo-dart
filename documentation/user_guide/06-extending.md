[Home](../../README.md) > User Guide

# Extending Jerelo

This guide shows you how to create custom computations, operators, and extensions that integrate seamlessly with Jerelo's composition model.

## Creating Custom Computations

The `Cont.fromRun` constructor gives you direct access to the runtime and observer, allowing you to create computations with custom execution logic.

### Basic Anatomy

```dart
Cont<E, F, T> myComputation<E, F, T>() {
  return Cont.fromRun((runtime, observer) {
    // Your custom logic here
    final result = performWork();
    observer.onThen(result);
  });
}
```

### The SafeObserver

The observer passed to `Cont.fromRun` is a `SafeObserver`, which provides:
- `observer.onThen(value)` — Signal success
- `observer.onElse(error)` — Signal a business-logic error
- `observer.onCrash(crash)` — Signal a crash
- `observer.isUsed()` — Returns `true` if any callback has already been invoked

Only this observer is guarded against duplicate calls; observers derived from it with `copyUpdate*` call their new callbacks every time. `fromRun` also catches only exceptions thrown synchronously by the run function: an exception thrown later inside a `Timer` or `Future` callback escapes to the zone, and the observer is never called. Wrap such callback bodies in `ContCrash.tryCatch` and pass the crash to `observer.onCrash`.

### Example: Delayed Computation

```dart
Cont<E, F, T> delay<E, F, T>(Duration duration, T value) {
  return Cont.fromRun((runtime, observer) {
    Timer(duration, () {
      observer.onThen(value);
    });
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
  return Cont.fromRun((runtime, observer) {
    File(path).readAsString().then(
      (contents) => observer.onThen(contents),
      onError: (error, stackTrace) {
        observer.onElse('Failed to read file: $error');
      },
    );
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
  // Cont.tailRecM loops without growing the stack, so even many
  // synchronous failures are safe. Fails with the last error.
  Cont<E, F, T> retry(int maxAttempts) {
    return Cont.tailRecM<E, F, int, T>(1, (attempt) {
      return thenMap<TailRec<int, T>>(TailRec.done).elseDo((error) {
        return attempt < maxAttempts
          ? Cont.of(TailRec.next(attempt + 1))
          : Cont.error(error);
      });
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

- **`run`** — The original run function (normally private and inaccessible)
- **`runtime`** — The runtime context (environment)
- **`observer`** — The observer receiving the three outcome callbacks

You can intercept execution by modifying the runtime or observer before passing them to `run`. Since `ContObserver` uses `copyUpdateOnThen`, `copyUpdateOnElse`, and `copyUpdateOnCrash` to derive new observers with selectively overridden callbacks.

`decorate` preserves the continuation's type signature (`Cont<E, F, A>` → `Cont<E, F, A>`). It is not meant for type-changing transformations — use `thenMap`, `thenDo`, etc. for those.

**Example: Execution timing**

```dart
extension TimingExtension<E, F, T> on Cont<E, F, T> {
  Cont<E, F, T> timed(void Function(Duration elapsed) onDuration) {
    return decorate((run, runtime, observer) {
      final stopwatch = Stopwatch()..start();

      run(
        runtime,
        observer
          .copyUpdateOnThen((value) {
            stopwatch.stop();
            onDuration(stopwatch.elapsed);
            observer.onThen(value);
          })
          .copyUpdateOnElse((error) {
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
    return decorate((run, runtime, observer) {
      if (predicate(runtime.env())) {
        run(runtime, observer);
      } else {
        observer.onElse(fallback);
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
    return decorate((run, runtime, observer) {
      print('[$label] Starting');
      run(
        runtime,
        observer
          .copyUpdateOnThen((value) {
            print('[$label] Success: $value');
            observer.onThen(value);
          })
          .copyUpdateOnElse((error) {
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

### Approach 3: Combine Both Approaches

```dart
extension AdvancedExtensions<E, T> on Cont<E, String, T> {
  // Retry with exponential backoff
  Cont<E, String, T> retryWithBackoff({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
  }) {
    Cont<E, String, T> attempt(int attemptsLeft, Duration currentDelay) {
      if (attemptsLeft <= 1) return this;

      return this.elseDo((error) {
        return delay<E, String, void>(currentDelay, null)
          .thenDo((_) => attempt(
            attemptsLeft - 1,
            currentDelay * 2,
          ))
          .elseDo((_) => Cont.error(error));
      });
    }

    return attempt(maxAttempts, initialDelay);
  }
}
```

---

## Using the Runtime

The `runtime` parameter passed to `Cont.fromRun` and `decorate` carries the environment:
- `runtime.env()` — Access the current environment
- `runtime.copyUpdateEnv(newEnv)` — Create a copy with a different environment

Core has no cancellation: once a computation starts, it runs until it reports an outcome. A cancellable `Cont` will be a separate feature.

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
      .decorate((run, runtime, observer) {
        // Add logging and timing via decorate
        print('[robustFetch] Starting operation...');
        final stopwatch = Stopwatch()..start();

        run(
          runtime,
          observer
            .copyUpdateOnThen((result) {
              stopwatch.stop();
              print('[robustFetch] Completed in ${stopwatch.elapsedMilliseconds}ms');
              observer.onThen(result);
            })
            .copyUpdateOnElse((error) {
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
