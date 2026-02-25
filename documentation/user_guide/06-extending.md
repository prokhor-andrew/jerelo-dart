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

### Key Rules for Using Observer

1. **Call exactly once**: You must call exactly one of `observer.onThen`, `observer.onElse`, or `observer.onCrash`
2. **Idempotent**: Calling more than once has no effect (the first call wins)
3. **Mandatory**: Failing to call the observer results in undefined behavior and lost errors (with exception to cancellation cases)
4. **Exception safety**: Exceptions thrown inside `Cont.fromRun` are automatically caught and routed to the crash channel — you don't need manual try-catch

### The SafeObserver

The observer passed to `Cont.fromRun` is a `SafeObserver`, which provides:
- `observer.onThen(value)` — Signal success
- `observer.onElse(error)` — Signal a business-logic error
- `observer.onCrash(crash)` — Signal a crash
- `observer.isUsed()` — Returns `true` if any callback has already been invoked

### Example: Delayed Computation

```dart
Cont<E, F, T> delay<E, F, T>(Duration duration, T value) {
  return Cont.fromRun((runtime, observer) {
    Timer(duration, () {
      if (runtime.isCancelled()) return;
      observer.onThen(value);
    });
  });
}

// Usage
delay(Duration(seconds: 2), 42).run(
  null,
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
  // Retry a computation N times on failure
  Cont<E, F, T> retry(int maxAttempts) {
    if (maxAttempts <= 1) return this;

    return this.elseDo((error) {
      return retry(maxAttempts - 1).elseDo((_) {
        return Cont.error(error);
      });
    });
  }

  // Execute with a timeout
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
    return this.thenTap((value) {
      print("[$label] $value");
      return Cont.of(());
    });
  }
}
```

### Approach 2: Use `decorate` for Low-Level Control

The `decorate` method is a natural transformation that wraps the execution of a continuation without changing its type. It gives you access to three things:

- **`run`** — The original run function (normally private and inaccessible)
- **`runtime`** — The runtime context (environment, cancellation)
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
  .run(null, onThen: print);
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
      if (attemptsLeft <= 0) return this;

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

## Cancellation with Runtime

The `runtime` parameter passed to `Cont.fromRun` provides access to cancellation state. This allows you to create computations that respect cancellation requests and clean up resources appropriately.

### Important: Cancellation Behavior

When a computation detects cancellation via `runtime.isCancelled()`, it must:
1. **Stop all work immediately**
2. **NOT call `observer.onThen()`, `observer.onElse()`, or `observer.onCrash()`** — cancelled computations do not emit anything
3. **Clean up any acquired resources**
4. **Return/exit silently**

Cancelled computations are effectively abandoned — they produce no result and no error. The consumer will not receive any callbacks.

### Checking Cancellation

```dart
Cont<E, F, List<T>> processLargeDataset<E, F, T>(List<T> items) {
  return Cont.fromRun((runtime, observer) {
    final results = <T>[];

    for (final item in items) {
      // Check if computation was cancelled
      if (runtime.isCancelled()) {
        // Don't emit anything - just exit silently
        return;
      }

      results.add(processItem(item));
    }

    observer.onThen(results);
  });
}
```

### Cancellation with Asynchronous Work

```dart
Cont<E, String, String> longRunningFetch<E>(String url) {
  return Cont.fromRun((runtime, observer) {
    // Check before starting work
    if (runtime.isCancelled()) {
      return; // Exit without emitting anything
    }

    final request = http.get(Uri.parse(url));

    request.then(
      (response) {
        // Check again before processing response
        if (runtime.isCancelled()) {
          return;
        }
        observer.onThen(response.body);
      },
      onError: (error, st) {
        if (!runtime.isCancelled()) {
          observer.onElse('Request failed: $error');
        }
      },
    );
  });
}
```

### Best Practices for Cancellation

1. **Check frequently**: In long-running operations, check `runtime.isCancelled()` periodically
2. **Don't emit on cancellation**: Never call observer methods when cancelled
3. **Clean up resources**: Release any acquired resources before exiting
4. **Exit silently**: Simply return from the function without emitting anything
5. **Check before emitting**: Always check cancellation status before calling observer methods, especially in async callbacks

### Using Runtime Features

The runtime provides:
- `runtime.env()` — Access the current environment
- `runtime.isCancelled()` — Check cancellation state
- `runtime.copyUpdateEnv(newEnv)` — Create a copy with a different environment
- `runtime.extendCancellation(anotherIsCancelled)` — Compose cancellation sources

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
