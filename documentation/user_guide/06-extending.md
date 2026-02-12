[Home](../../README.md) > User Guide

# Extending Jerelo

This guide shows you how to create custom computations, operators, and extensions that integrate seamlessly with Jerelo's composition model.

## Creating Custom Computations

The `Cont.fromRun` constructor gives you direct access to the runtime and observer, allowing you to create computations with custom execution logic.

### Basic Anatomy

```dart
Cont<E, T> myComputation<E, T>() {
  return Cont.fromRun((runtime, observer) {
    // Your custom logic here

    try {
      // Perform computation
      final result = performWork();

      // Signal success
      observer.onThen(result);
    } catch (error, stackTrace) {
      // Signal termination
      observer.onElse([ContError.withStackTrace(error, stackTrace)]);
    }
  });
}
```

### Key Rules for Using Observer

1. **Call exactly once**: You must call either `observer.onThen` or `observer.onElse` exactly once
2. **Idempotent**: Calling more than once has no effect (the first call wins)
3. **Mandatory**: Failing to call the observer results in undefined behavior and lost errors (with exception to cancellation cases)

### Example: Delayed Computation

```dart
Cont<E, T> delay<E, T>(Duration duration, T value) {
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
Cont<E, String> readFile<E>(String path) {
  return Cont.fromRun((runtime, observer) {
    File(path).readAsString().then(
      (contents) => observer.onThen(contents),
      onError: (error, stackTrace) {
        observer.onElse([ContError.withStackTrace(error, stackTrace)]);
      },
    );
  });
}
```

---

## Creating Custom Operators

You can create custom operators by combining existing Jerelo operators or by using `decor` for lower-level control.

### Approach 1: Compose Existing Operators

Most custom operators can be built by composing existing ones:

```dart
extension MyContExtensions<E, T> on Cont<E, T> {
  // Retry a computation N times on failure
  Cont<E, T> retry(int maxAttempts) {
    if (maxAttempts <= 1) return this;

    return this.elseDo((errors) {
      return retry(maxAttempts - 1).elseDo((_) {
        // If all retries fail, return original errors
        return Cont.stop(errors);
      });
    });
  }

  // Execute with a timeout
  Cont<E, T> timeout(Duration duration, T defaultValue) {
    final timeoutCont = delay<E, T>(duration, defaultValue);

    return Cont.either(
      this,
      timeoutCont,
      policy: ContEitherPolicy.quitFast(),
    );
  }

  // Log value for debugging without changing it
  Cont<E, T> debug(String label) {
    return this.thenTap((value) {
      print("[$label] $value");
      return Cont.of(());
    });
  }
}

// Usage
getUserData(userId)
  .retry(3)
  .timeout(Duration(seconds: 5), User.empty())
  .debug("User fetched")
  .run((), onThen: print);
```

### Approach 2: Use `decor` for Low-Level Control

The `decor` method is a natural transformation that wraps the execution of a continuation without changing its type. It gives you access to three things:

- **`run`** - The original run function (normally private and inaccessible)
- **`runtime`** - The runtime context (environment, cancellation, panic handler)
- **`observer`** - The observer receiving success/termination callbacks

You can intercept execution by modifying the runtime or observer before passing them to `run`. Since `ContObserver` has a private constructor, new observers are created from the existing one using `copyUpdateOnThen` and `copyUpdateOnElse`.

`decor` preserves the continuation's type signature (`Cont<E, A>` -> `Cont<E, A>`). It is not meant for type-changing transformations - use `thenMap`, `thenDo`, etc. for those.

**Example: Execution timing**

```dart
extension TimingExtension<E, T> on Cont<E, T> {
  Cont<E, T> timed(void Function(Duration elapsed) onDuration) {
    return decor((run, runtime, observer) {
      final stopwatch = Stopwatch()..start();

      run(
        runtime,
        observer
          .copyUpdateOnThen((value) {
            stopwatch.stop();
            onDuration(stopwatch.elapsed);
            observer.onThen(value);
          })
          .copyUpdateOnElse((errors) {
            stopwatch.stop();
            observer.onElse(errors);
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
extension ConditionalExtension<E, T> on Cont<E, T> {
  Cont<E, T> onlyWhen(bool Function(E env) predicate) {
    return decor((run, runtime, observer) {
      if (predicate(runtime.env())) {
        run(runtime, observer);
      } else {
        observer.onElse();
      }
    });
  }
}

// Usage: only run in production
fetchAnalytics()
  .onlyWhen((env) => env.isProduction)
  .run(config, onThen: print);
```

**Example: Logging middleware**

```dart
extension LoggingExtension<E, T> on Cont<E, T> {
  Cont<E, T> logged(String label) {
    return decor((run, runtime, observer) {
      print('[$label] Starting');
      run(
        runtime,
        observer
          .copyUpdateOnThen((value) {
            print('[$label] Success: $value');
            observer.onThen(value);
          })
          .copyUpdateOnElse((errors) {
            print('[$label] Failed: ${errors.length} error(s)');
            observer.onElse(errors);
          }),
      );
    });
  }
}
```

### Approach 3: Combine Both Approaches

```dart
extension AdvancedExtensions<E, T> on Cont<E, T> {
  // Retry with exponential backoff
  Cont<E, T> retryWithBackoff({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 100),
  }) {
    Cont<E, T> attempt(int attemptsLeft, Duration currentDelay) {
      if (attemptsLeft <= 0) return this;

      return this.elseDo((errors) {
        return delay<E, void>(currentDelay, null)
          .thenDo((_) => attempt(
            attemptsLeft - 1,
            currentDelay * 2,
          ))
          .elseDo((_) => Cont.stop<E, T>(errors));
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
2. **NOT call `observer.onThen()` or `observer.onElse()`** - cancelled computations do not emit anything
3. **Clean up any acquired resources**
4. **Return/exit silently**

Cancelled computations are effectively abandoned - they produce no result and no error. The consumer will not receive any callbacks.

### Checking Cancellation

```dart
Cont<E, List<T>> processLargeDataset<E, T>(List<T> items) {
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
Cont<E, String> longRunningFetch<E>(String url) {
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
          // Don't emit - computation was cancelled
          return;
        }
        observer.onThen(response.body);
      },
      onError: (error, st) {
        // Only emit errors if not cancelled
        if (!runtime.isCancelled()) {
          observer.onElse([ContError.withStackTrace(error, st)]);
        }
      },
    );
  });
}
```

### Best Practices for Cancellation

1. **Check frequently**: In long-running operations, check `runtime.isCancelled()` periodically
2. **Don't emit on cancellation**: Never call `observer.onThen()` or `observer.onElse()` when cancelled
3. **Clean up resources**: Release any acquired resources before exiting
4. **Exit silently**: Simply return from the function without emitting anything
5. **Check before emitting**: Always check cancellation status before calling observer methods, especially in async callbacks

### Example: Cancellable Operation with Resource Cleanup

```dart
Cont<E, Data> processWithCleanup<E>() {
  return Cont.fromRun((runtime, observer) {
    final resource = acquireExpensiveResource();

    try {
      // Perform work in chunks
      for (final chunk in workChunks) {
        if (runtime.isCancelled()) {
          // Clean up and exit without emitting
          resource.dispose();
          return;
        }

        processChunk(chunk, resource);
      }

      // Success - emit result
      observer.onThen(resource.extractData());
    } catch (error, st) {
      // Only emit error if not cancelled
      if (!runtime.isCancelled()) {
        observer.onElse([ContError.withStackTrace(error, st)]);
      }
    } finally {
      // Always clean up
      resource.dispose();
    }
  });
}
```

### Example: Cancellable Polling

```dart
Cont<E, T> pollUntil<E, T>({
  required Cont<E, T> computation,
  required bool Function(T) predicate,
  Duration interval = const Duration(seconds: 1),
  int maxAttempts = 10,
}) {
  return Cont.fromRun((runtime, observer) {
    int attempts = 0;

    void poll() {
      // Check cancellation - exit without emitting
      if (runtime.isCancelled()) {
        return;
      }

      if (attempts >= maxAttempts) {
        observer.onElse([
          ContError.capture("Max attempts reached")
        ]);
        return;
      }

      attempts++;

      computation.run(
        runtime.env(), // Forward environment
        onElse: (errors) {
          // Check cancellation before emitting errors
          if (!runtime.isCancelled()) {
            observer.onElse(errors);
          }
        },
        onThen: (value) {
          // Check cancellation before processing value
          if (runtime.isCancelled()) {
            return;
          }

          if (predicate(value)) {
            observer.onThen(value);
          } else {
            Timer(interval, poll);
          }
        },
      );
    }

    poll();
  });
}

// Usage
pollUntil(
  computation: checkJobStatus(jobId),
  predicate: (status) => status.isComplete,
  interval: Duration(seconds: 2),
  maxAttempts: 30,
).run((), onThen: (status) {
  print("Job completed: $status");
});
```

### Using Runtime Features

The runtime also provides:
- `runtime.env()` - Access the current environment
- `runtime.onPanic` - Access the panic handler

These can be useful when forwarding context to nested computations within custom implementations.

---

## Complete Custom Operator Example

Here's a comprehensive example combining multiple concepts:

```dart
extension RobustOperations<E, T> on Cont<E, T> {
  /// Retry with exponential backoff and logging
  Cont<E, T> robustFetch({
    int maxRetries = 3,
    Duration initialBackoff = const Duration(milliseconds: 100),
  }) {
    return this
      .retryWithBackoff(
        maxAttempts: maxRetries,
        initialDelay: initialBackoff,
      )
      .decor((run, runtime, observer) {
        // Add logging and timing via decor
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
            .copyUpdateOnElse((errors) {
              stopwatch.stop();
              print('[robustFetch] Failed after ${stopwatch.elapsedMilliseconds}ms: ${errors.length} error(s)');
              observer.onElse(errors);
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
    onElse: (errors) => print('Failed: $errors'),
  );
```

---

## Next Steps

Now that you understand how to extend Jerelo, see:
- **[Complete Examples](07-examples.md)** - Real-world patterns and use cases
- **[API Reference](../api_reference/)** - Full API documentation
- **[Core Operations](03-core-operations.md)** - Review built-in operators for composition ideas
