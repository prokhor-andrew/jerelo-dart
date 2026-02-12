[Home](../../README.md) > User Guide

# Complete Examples & Patterns

This guide provides comprehensive real-world examples that demonstrate Jerelo's capabilities.

## Complete Example: User Management System

Here's a comprehensive example bringing it all together:

```dart
class AppConfig {
  final String apiUrl;
  final String cacheDir;
  final Duration timeout;

  AppConfig(this.apiUrl, this.cacheDir, this.timeout);
}

// Fetch user with retry and caching
Cont<AppConfig, User> getUser(String userId) {
  return Cont.ask<AppConfig>()
    .thenDoWithEnv((config, _) {
      // Try API first
      return fetchFromApi(config.apiUrl, userId, config.timeout)
        .thenIf((user) => user.isValid)
        .elseTapWithEnv((env, errors) {
          // Log errors in background
          return logToFile(env.cacheDir, errors);
        })
        .elseDoWithEnv((env, errors) {
          // Fallback to cache
          return loadFromCache(env.cacheDir, userId);
        });
    })
    .thenTapWithEnv((env, user) {
      // Update cache in background
      return saveToCache(env.cacheDir, user)
        .elseFork((_) => Cont.of(())); // ignore cache failures
    });
}

// Fetch multiple users in parallel
Cont<AppConfig, List<User>> getUsers(List<String> userIds) {
  final continuations = userIds.map((id) => getUser(id)).toList();
  return Cont.all(
    continuations,
    policy: ContBothPolicy.quitFast(), // Fails fast if any user fetch fails
  );
}

// Process users with resource management
Cont<AppConfig, Report> processUsers(List<String> userIds) {
  return Cont.bracket<AppConfig, Database, Report>(
    acquire: openDatabase(),
    release: (db) => closeDatabase(db),
    use: (db) {
      return getUsers(userIds)
        .thenDo((users) => processInDb(db, users))
        .thenDo((results) => generateReport(results))
        .thenWhile((report) => !report.isComplete)
        .thenTapWithEnv((env, report) {
          return notifyComplete(env.apiUrl, report);
        });
    },
  );
}

// Run the program
final config = AppConfig(
  "https://api.example.com",
  "/tmp/cache",
  Duration(seconds: 5),
);

final token = processUsers(['user1', 'user2', 'user3']).run(
  config,
  onElse: (errors) {
    print("Failed: ${errors.length} error(s)");
    for (final e in errors) {
      print("  ${e.error}");
    }
  },
  onThen: (report) {
    print("Success: $report");
  },
);

// Cancel the computation if needed (e.g., on shutdown)
// token.cancel();
```

This example demonstrates:
- Environment management (AppConfig)
- Error handling with fallbacks (elseDo)
- Side effects (thenTap, elseFork)
- Conditional execution (thenIf)
- Parallel execution with policies (Cont.all with ContBothPolicy.quitFast)
- Resource management (bracket)
- Looping (thenWhile)
- WithEnv variants for accessing config
- Cancellation via `ContCancelToken` returned by `run`

---

## Common Patterns

### Pattern 1: API Client with Retry and Timeout

```dart
class ApiClient<E> {
  final String baseUrl;
  final Duration timeout;
  final int maxRetries;

  ApiClient(this.baseUrl, this.timeout, this.maxRetries);

  Cont<E, T> get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return _makeRequest(path)
      .thenMap((response) => fromJson(response))
      .timeout(timeout)
      .retry(maxRetries);
  }

  Cont<E, Map<String, dynamic>> _makeRequest(String path) {
    return Cont.fromRun((runtime, observer) {
      http.get(Uri.parse('$baseUrl$path')).then(
        (response) {
          if (response.statusCode == 200) {
            observer.onThen(jsonDecode(response.body));
          } else {
            observer.onElse([
              ContError.capture('HTTP ${response.statusCode}')
            ]);
          }
        },
        onError: (error, st) {
          observer.onElse([ContError.withStackTrace(error, st)]);
        },
      );
    });
  }
}

// Usage
final client = ApiClient('https://api.example.com', Duration(seconds: 5), 3);

client.get('/users/123', User.fromJson).run(
  (),
  onThen: (user) => print('User: $user'),
  onElse: (errors) => print('Failed: $errors'),
);
```

### Pattern 2: Cache-Then-Network Strategy

```dart
Cont<E, T> cacheFirst<E, T>(
  String key,
  Cont<E, T> network,
  Cache cache,
) {
  return Cont.fromRun<E, T>((runtime, observer) {
    // Try cache first
    final cached = cache.get<T>(key);
    if (cached != null) {
      observer.onThen(cached);

      // Update cache in background
      network.run(
        runtime.env(),
        onThen: (fresh) => cache.set(key, fresh),
      );
      return;
    }

    // Cache miss - fetch from network
    network.run(
      runtime.env(),
      onThen: (value) {
        cache.set(key, value);
        observer.onThen(value);
      },
      onElse: observer.onElse,
    );
  });
}

// Usage
cacheFirst(
  'user:123',
  fetchUserFromApi('123'),
  cache,
).run((), onThen: displayUser);
```

### Pattern 3: Validation Pipeline

```dart
Cont<E, T> validate<E, T>(
  T value,
  List<bool Function(T)> validators,
  List<String> errorMessages,
) {
  return Cont.of<E, T>(value).thenDo((val) {
    final errors = <ContError>[];

    for (var i = 0; i < validators.length; i++) {
      if (!validators[i](val)) {
        errors.add(ContError.capture(errorMessages[i]));
      }
    }

    return errors.isEmpty
      ? Cont.of<E, T>(val)
      : Cont.stop<E, T>(errors);
  });
}

// Usage
Cont<(), UserInput> validateUserInput(UserInput input) {
  return validate(
    input,
    [
      (i) => i.email.contains('@'),
      (i) => i.password.length >= 8,
      (i) => i.age >= 18,
    ],
    [
      'Invalid email format',
      'Password must be at least 8 characters',
      'Must be 18 or older',
    ],
  );
}

validateUserInput(userInput).run(
  (),
  onThen: processRegistration,
  onElse: (errors) {
    for (final error in errors) {
      print('Validation error: ${error.error}');
    }
  },
);
```

### Pattern 4: Parallel Task Execution with Progress

```dart
class ProgressTracker {
  int completed = 0;
  final int total;
  final void Function(double) onProgress;

  ProgressTracker(this.total, this.onProgress);

  void increment() {
    completed++;
    onProgress(completed / total);
  }
}

Cont<E, List<T>> parallelWithProgress<E, T>(
  List<Cont<E, T>> tasks,
  void Function(double) onProgress,
) {
  final tracker = ProgressTracker(tasks.length, onProgress);

  final trackedTasks = tasks.map((task) {
    return task.thenTap((result) {
      tracker.increment();
      return Cont.of(());
    });
  }).toList();

  return Cont.all(trackedTasks, policy: ContBothPolicy.quitFast());
}

// Usage
final downloadTasks = files.map((file) => downloadFile(file)).toList();

parallelWithProgress(
  downloadTasks,
  (progress) => print('Progress: ${(progress * 100).toInt()}%'),
).run(
  (),
  onThen: (results) => print('All downloads complete'),
  onElse: (errors) => print('Download failed: $errors'),
);
```

### Pattern 5: Circuit Breaker

```dart
class CircuitBreaker<E, T> {
  final Duration resetTimeout;
  final int failureThreshold;

  int _failureCount = 0;
  DateTime? _openedAt;
  bool _isOpen = false;

  CircuitBreaker({
    required this.resetTimeout,
    required this.failureThreshold,
  });

  Cont<E, T> protect(Cont<E, T> operation) {
    return Cont.fromRun((runtime, observer) {
      // Check if circuit is open
      if (_isOpen) {
        final now = DateTime.now();
        if (_openedAt != null &&
            now.difference(_openedAt!) > resetTimeout) {
          // Try to close circuit
          _isOpen = false;
          _failureCount = 0;
        } else {
          // Circuit still open
          observer.onElse([
            ContError.capture('Circuit breaker is open')
          ]);
          return;
        }
      }

      // Execute operation
      operation.run(
        runtime.env(),
        onThen: (value) {
          // Reset on success
          _failureCount = 0;
          observer.onThen(value);
        },
        onElse: (errors) {
          // Increment failure count
          _failureCount++;

          if (_failureCount >= failureThreshold) {
            _isOpen = true;
            _openedAt = DateTime.now();
          }

          observer.onElse(errors);
        },
      );
    });
  }
}

// Usage
final breaker = CircuitBreaker<(), Data>(
  resetTimeout: Duration(seconds: 30),
  failureThreshold: 3,
);

breaker.protect(fetchFromUnreliableService()).run(
  (),
  onThen: processData,
  onElse: handleError,
);
```

### Pattern 6: Request Deduplication

```dart
class RequestDeduplicator<K, E, T> {
  final Map<K, List<ContObserver<T>>> _pending = {};

  Cont<E, T> deduplicate(K key, Cont<E, T> operation) {
    return Cont.fromRun((runtime, observer) {
      // Check if request is already in flight
      if (_pending.containsKey(key)) {
        // Add observer to pending list
        _pending[key]!.add(observer);
        return;
      }

      // Start new request
      _pending[key] = [observer];

      operation.run(
        runtime.env(),
        onThen: (value) {
          // Notify all waiting observers
          for (final obs in _pending[key]!) {
            obs.onThen(value);
          }
          _pending.remove(key);
        },
        onElse: (errors) {
          // Notify all waiting observers
          for (final obs in _pending[key]!) {
            obs.onElse(errors);
          }
          _pending.remove(key);
        },
      );
    });
  }
}

// Usage
final deduper = RequestDeduplicator<String, (), User>();

// Multiple concurrent requests for same user
deduper.deduplicate('user:123', fetchUser('123')).run((), onThen: display);
deduper.deduplicate('user:123', fetchUser('123')).run((), onThen: display);
deduper.deduplicate('user:123', fetchUser('123')).run((), onThen: display);
// Only one actual API call is made
```

### Pattern 7: Rate Limiting

```dart
class RateLimiter<E, T> {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _timestamps = Queue();

  RateLimiter(this.maxRequests, this.window);

  Cont<E, T> limit(Cont<E, T> operation) {
    return Cont.fromRun((runtime, observer) {
      final now = DateTime.now();

      // Remove old timestamps outside the window
      while (_timestamps.isNotEmpty &&
             now.difference(_timestamps.first) > window) {
        _timestamps.removeFirst();
      }

      // Check if we're at the limit
      if (_timestamps.length >= maxRequests) {
        observer.onElse([
          ContError.capture('Rate limit exceeded')
        ]);
        return;
      }

      // Record this request
      _timestamps.add(now);

      // Execute operation
      operation.run(
        runtime.env(),
        onThen: observer.onThen,
        onElse: observer.onElse,
      );
    });
  }
}

// Usage
final limiter = RateLimiter<(), Data>(
  5, // max 5 requests
  Duration(seconds: 1), // per second
);

limiter.limit(fetchData()).run(
  (),
  onThen: processData,
  onElse: handleError,
);
```

---

## Best Practices

### 1. Prefer Composition Over Custom Implementation

```dart
// Good: Compose existing operators
Cont<E, T> retryWithLogging<E, T>(Cont<E, T> operation, int maxRetries) {
  return operation
    .elseTap((errors) {
      print('Operation failed: $errors');
      return Cont.of(());
    })
    .retry(maxRetries)
    .thenTap((result) {
      print('Operation succeeded: $result');
      return Cont.of(());
    });
}

// Less ideal: Building everything from scratch
// (unless you truly need custom behavior)
```

### 2. Use Environment for Cross-Cutting Concerns

```dart
// Good: Thread configuration through environment
class AppServices {
  final Logger logger;
  final Analytics analytics;
  final Database database;
}

Cont<AppServices, T> operation() {
  return Cont.ask<AppServices>().thenDoWithEnv((services, _) {
    return services.database.query(...).thenTapWithEnv((services, result) {
      return services.analytics.track('query_completed');
    });
  });
}

// Less ideal: Passing dependencies explicitly through every function
```

### 3. Make Cancellation-Aware Long Operations

```dart
// Good: Check cancellation periodically
Cont<E, List<T>> processLarge<E, T>(List<T> items) {
  return Cont.fromRun((runtime, observer) {
    final results = <T>[];

    for (final item in items) {
      if (runtime.isCancelled()) return; // Exit cleanly
      results.add(process(item));
    }

    observer.onThen(results);
  });
}
```

### 4. Use Bracket for Resource Management

```dart
// Good: Guaranteed cleanup
Cont<E, T> withConnection<E, T>(Cont<Connection, T> operation) {
  return Cont.bracket(
    acquire: openConnection(),
    release: (conn) => closeConnection(conn),
    use: (conn) => operation.scope(conn),
  );
}

// Less ideal: Manual cleanup (easy to miss error paths)
```

---
