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
Cont<AppConfig, String, User> getUser(String userId) {
  return Cont.askThen<AppConfig, String>()
    .thenDo((config) {
      return fetchFromApi(config.apiUrl, userId, config.timeout);
    })
    .thenIf((user) => user.isValid, fallback: 'invalid user')
    .elseTapWithEnv((env, error) {
      // Log errors in background
      return logToFile(env.cacheDir, error);
    })
    .elseDoWithEnv0((env) {
      // Fallback to cache
      return loadFromCache(env.cacheDir, userId);
    });
    .thenTapWithEnv((env, user) {
      // Update cache in background
      return saveToCache(env.cacheDir, user);
    });
}

// Fetch multiple users in parallel
Cont<AppConfig, String, List<User>> getUsers(List<String> userIds) {
  final continuations = userIds.map((id) => getUser(id)).toList();
  return Cont.all(
    continuations,
    policy: OkPolicy.quitFast<String>(),
  );
}

// Process users with resource management
Cont<AppConfig, String, Report> processUsers(List<String> userIds) {
  return Cont.bracket<Database, AppConfig, String, Report>(
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
  onCrash: (crash) {
    print("Crash: $crash");
  },
  onElse: (error) {
    print("Failed: $error");
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
- Side effects (thenTap)
- Conditional execution (thenIf with fallback)
- Parallel execution with policies (Cont.all with OkPolicy.quitFast)
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

  Cont<E, String, T> get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return _makeRequest(path)
      .thenMap((response) => fromJson(response));
  }

  Cont<E, String, Map<String, dynamic>> _makeRequest(String path) {
    return Cont.fromRun((runtime, observer) {
      http.get(Uri.parse('$baseUrl$path')).then(
        (response) {
          if (runtime.isCancelled()) return;

          if (response.statusCode == 200) {
            observer.onThen(jsonDecode(response.body));
          } else {
            observer.onElse('HTTP ${response.statusCode}');
          }
        },
        onError: (error, st) {
          if (!runtime.isCancelled()) {
            observer.onElse('Request failed: $error');
          }
        },
      );
    });
  }
}

// Usage
final client = ApiClient('https://api.example.com', Duration(seconds: 5), 3);

client.get('/users/123', User.fromJson).run(
  null,
  onThen: (user) => print('User: $user'),
  onElse: (error) => print('Failed: $error'),
);
```

### Pattern 2: Cache-Then-Network Strategy

```dart
Cont<E, String, T> cacheFirst<E, T>(
  String key,
  Cont<E, String, T> network,
  Cache cache,
) {
  return Cont.fromRun<E, String, T>((runtime, observer) {
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
).run(null, onThen: displayUser);
```

### Pattern 3: Validation Pipeline

```dart
Cont<E, List<String>, T> validate<E, T>(
  T value,
  List<bool Function(T)> validators,
  List<String> errorMessages,
) {
  return Cont.of<E, List<String>, T>(value).thenDo((val) {
    final errors = <String>[];

    for (var i = 0; i < validators.length; i++) {
      if (!validators[i](val)) {
        errors.add(errorMessages[i]);
      }
    }

    return errors.isEmpty
      ? Cont.of<E, List<String>, T>(val)
      : Cont.error<E, List<String>, T>(errors);
  });
}

// Usage
Cont<void, List<String>, UserInput> validateUserInput(UserInput input) {
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
  null,
  onThen: processRegistration,
  onElse: (errors) {
    for (final error in errors) {
      print('Validation error: $error');
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

Cont<E, F, List<T>> parallelWithProgress<E, F, T>(
  List<Cont<E, F, T>> tasks,
  void Function(double) onProgress,
) {
  final tracker = ProgressTracker(tasks.length, onProgress);

  final trackedTasks = tasks.map((task) {
    return task.thenTap((result) {
      tracker.increment();
      return Cont.of(());
    });
  }).toList();

  return Cont.all(trackedTasks, policy: OkPolicy.quitFast<F>());
}

// Usage
final downloadTasks = files.map((file) => downloadFile(file)).toList();

parallelWithProgress(
  downloadTasks,
  (progress) => print('Progress: ${(progress * 100).toInt()}%'),
).run(
  null,
  onThen: (results) => print('All downloads complete'),
  onElse: (error) => print('Download failed: $error'),
);
```

### Pattern 5: Circuit Breaker

```dart
class CircuitBreaker<E, F, T> {
  final Duration resetTimeout;
  final int failureThreshold;
  final F openCircuitError;

  int _failureCount = 0;
  DateTime? _openedAt;
  bool _isOpen = false;

  CircuitBreaker({
    required this.resetTimeout,
    required this.failureThreshold,
    required this.openCircuitError,
  });

  Cont<E, F, T> protect(Cont<E, F, T> operation) {
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
          observer.onElse(openCircuitError);
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
        onElse: (error) {
          // Increment failure count
          _failureCount++;

          if (_failureCount >= failureThreshold) {
            _isOpen = true;
            _openedAt = DateTime.now();
          }

          observer.onElse(error);
        },
      );
    });
  }
}

// Usage
final breaker = CircuitBreaker<void, String, Data>(
  resetTimeout: Duration(seconds: 30),
  failureThreshold: 3,
  openCircuitError: 'Circuit breaker is open',
);

breaker.protect(fetchFromUnreliableService()).run(
  null,
  onThen: processData,
  onElse: handleError,
);
```

### Pattern 6: Rate Limiting

```dart
class RateLimiter<E, F, T> {
  final int maxRequests;
  final Duration window;
  final F rateLimitError;
  final Queue<DateTime> _timestamps = Queue();

  RateLimiter(this.maxRequests, this.window, this.rateLimitError);

  Cont<E, F, T> limit(Cont<E, F, T> operation) {
    return Cont.fromRun((runtime, observer) {
      final now = DateTime.now();

      // Remove old timestamps outside the window
      while (_timestamps.isNotEmpty &&
             now.difference(_timestamps.first) > window) {
        _timestamps.removeFirst();
      }

      // Check if we're at the limit
      if (_timestamps.length >= maxRequests) {
        observer.onElse(rateLimitError);
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
final limiter = RateLimiter<void, String, Data>(
  5, // max 5 requests
  Duration(seconds: 1), // per second
  'Rate limit exceeded',
);

limiter.limit(fetchData()).run(
  null,
  onThen: processData,
  onElse: handleError,
);
```

---

## Best Practices

### 1. Prefer Composition Over Custom Implementation

```dart
// Good: Compose existing operators
Cont<E, String, T> retryWithLogging<E, T>(Cont<E, String, T> operation, int maxRetries) {
  return operation
    .elseTap((error) {
      print('Operation failed: $error');
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

Cont<AppServices, String, T> operation<T>() {
  return Cont.askThen<AppServices, String>().thenDoWithEnv((services, _) {
    return services.database.query('...').thenTapWithEnv((services, result) {
      return services.analytics.track('query_completed');
    });
  });
}

// Less ideal: Passing dependencies explicitly through every function
```

### 3. Make Cancellation-Aware Long Operations

```dart
// Good: Check cancellation periodically
Cont<E, F, List<T>> processLarge<E, F, T>(List<T> items) {
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
Cont<E, F, T> withConnection<E, F, T>(Cont<Connection, F, T> operation) {
  return Cont.bracket(
    acquire: openConnection(),
    release: (conn) => closeConnection(conn),
    use: (conn) => operation.withEnv(conn),
  );
}

// Less ideal: Manual cleanup (easy to miss error paths)
```

### 5. Use Typed Errors for Business Logic

```dart
// Good: Typed error enum
enum UserError { notFound, unauthorized, invalidInput }

Cont<void, UserError, User> getUser(String id) {
  return Cont.fromRun((runtime, observer) {
    if (id.isEmpty) {
      observer.onElse(UserError.invalidInput);
      return;
    }
    // ...
  });
}

// Handle specific errors
getUser(userId)
  .elseUnless((error) => error == UserError.notFound, fallback: User.guest())
  .run(null, onThen: display, onElse: showError);
```

---
