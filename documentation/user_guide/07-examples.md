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

### Pattern 1: Wrapping an Async API

`Cont.fromRun` is the bridge between callback-based code and Jerelo's composition model. Check cancellation inside every async callback before emitting.

```dart
Cont<E, String, List<Post>> fetchPosts<E>(String authorId) {
  return Cont.fromRun((runtime, observer) {
    http.get(Uri.parse('/posts?author=$authorId')).then(
      (response) {
        if (runtime.isCancelled()) return;
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          observer.onThen(data.map(Post.fromJson).toList());
        } else {
          observer.onElse('HTTP ${response.statusCode}');
        }
      },
      onError: (e, _) {
        if (!runtime.isCancelled()) observer.onElse('$e');
      },
    );
  });
}

// Usage
fetchPosts<()>(authorId)
  .thenMap((posts) => posts.where((p) => p.published).toList())
  .run((), onThen: displayPosts, onElse: showError);
```

### Pattern 2: Error Fallback Chain

`elseDo` recovers from failure with an alternative computation. Chaining it creates a prioritized sequence — each step is only attempted if the previous one failed.

```dart
Cont<E, String, User> getUser<E>(String id) {
  return readFromCache(id)
    .elseDo((_) => fetchFromNetwork(id)
      .thenTap((user) => writeToCache(id, user)),
    )
    .elseDo((_) => Cont.of(User.guest()));
}

getUser<()>(userId).run((), onThen: display, onElse: showError);
```

Execution order: cache → network (write-through on success) → guest fallback.

### Pattern 3: Validation Pipeline

Two strategies, depending on whether you want to stop at the first broken rule or surface every error at once.

**Fail-fast** — `thenIf` short-circuits on the first failure; later rules never run:

```dart
Cont<E, String, UserInput> validateInput<E>(UserInput input) {
  return Cont.of(input)
    .thenIf((i) => i.email.contains('@'), fallback: 'Invalid email')
    .thenIf((i) => i.password.length >= 8,  fallback: 'Password too short')
    .thenIf((i) => i.age >= 18,             fallback: 'Must be 18 or older');
}

validateInput<()>(input).run(
  (),
  onThen: submitRegistration,
  onElse: showValidationError,
);
```

**Collect all** — `Cont.all` with `OkPolicy.runAll` runs every rule in parallel and merges every error into one report:

```dart
Cont<E, String, UserInput> validateInput<E>(UserInput input) {
  Cont<E, String, UserInput> check(bool passes, String error) =>
    passes ? Cont.of(input) : Cont.error(error);

  return Cont.all(
    [
      check(input.email.contains('@'),  'Invalid email'),
      check(input.password.length >= 8, 'Password too short'),
      check(input.age >= 18,            'Must be 18 or older'),
    ],
    policy: OkPolicy.runAll(
      (e1, e2) => '$e1\n$e2',
      shouldFavorCrash: false,
    ),
  ).thenMap((results) => results.first);
}

validateInput<()>(input).run(
  (),
  onThen: submitRegistration,
  onElse: showValidationError, // receives all errors joined by '\n'
);
```

### Pattern 4: Parallel Execution

`Cont.all` runs a list of computations concurrently and collects their results. Add `thenTap` to each task to observe progress as completions arrive.

```dart
Cont<(), F, List<T>> withProgress<F, T>(
  List<Cont<(), F, T>> tasks,
  void Function(int done, int total) onProgress,
) {
  return Cont.fromDeferred(() {
    int done = 0;
    final tracked = tasks.map((task) =>
      task.thenTap((_) {
        onProgress(++done, tasks.length);
        return Cont.of(());
      })
    ).toList();
    return Cont.all(tracked, policy: OkPolicy.quitFast());
  });
}

// Usage
withProgress(
  files.map(downloadFile).toList(),
  (done, total) => updateProgressBar(done / total),
).run((), onThen: processAll, onElse: handleError);
```

### Pattern 5: Racing Computations

`Cont.either` runs two computations concurrently and takes the first to succeed. Use it to race a primary source against a fallback, or to implement timeouts.

```dart
// Race remote config against local — whichever resolves first wins.
// If both fail, report the remote error.
Cont<(), String, Config> loadConfig() {
  return Cont.either(
    fetchRemoteConfig(),
    readLocalConfig(),
    (remoteError, _) => remoteError,
    policy: OkPolicy.quitFast(),
  );
}

loadConfig().run((), onThen: applyConfig, onElse: showError);
```

### Pattern 6: Resource Management

`Cont.bracket` guarantees that `release` runs regardless of whether `use` succeeds, fails, or crashes. It is the correct tool whenever a computation acquires a resource that must be released.

```dart
Cont<(), String, Report> generateReport(Query query) {
  return Cont.bracket(
    acquire: openDatabaseConnection(),
    release: (conn) => closeConnection(conn),
    use: (conn) => conn.execute(query).thenMap(Report.fromRows),
  );
}

generateReport(query).run((), onThen: publish, onElse: showError);
```

---

## Best Practices

### 1. Prefer Composition to Custom Implementation

```dart
// Build on existing operators rather than reaching for Cont.fromRun
fetchData()
  .elseTap((error) {
    print('Attempt failed: $error');
    return Cont.of(());
  })
  .retry(3)
  .run((), onThen: process, onElse: showError);
```

### 2. Use Environment for Cross-Cutting Concerns

```dart
// Thread dependencies through the environment rather than function parameters
class AppEnv { final Logger logger; final Database db; }

Cont<AppEnv, String, List<Order>> fetchOrders(String userId) {
  return Cont.askThen<AppEnv, String>().thenDo((env) {
    return env.db.query('SELECT * FROM orders WHERE user = ?', [userId]);
  }).thenTapWithEnv((env, orders) {
    return env.logger.info('Loaded ${orders.length} orders');
  });
}
```

### 3. Compose Cancellation Sources

`runtime.extendCancellation` lets you add a local cancellation condition on top of the one inherited from the parent. The resulting runtime reports cancelled when either source is true — the inner computation never needs to know about the outer one.

```dart
// Cancel the inner computation when the deadline passes,
// while still propagating the parent's cancellation signal.
extension WithDeadline<E, F, T> on Cont<E, F, T> {
  Cont<E, F, T> withDeadline(DateTime deadline) {
    return decorate((run, runtime, observer) {
      final extended = runtime.extendCancellation(
        () => DateTime.now().isAfter(deadline),
      );
      run(extended, observer);
    });
  }
}

// Usage
fetchReportData()
  .withDeadline(DateTime.now().add(Duration(seconds: 5)))
  .run((), onThen: display, onElse: showError);
```

### 4. Use Bracket for Resource Management

```dart
// Guaranteed cleanup — release runs even if use crashes
Cont<E, F, T> withConnection<E, F, T>(Cont<Connection, F, T> operation) {
  return Cont.bracket(
    acquire: openConnection(),
    release: (conn) => closeConnection(conn),
    use: (conn) => operation.withEnv(conn),
  );
}
```

### 5. Use Typed Errors for Business Logic

```dart
enum UserError { notFound, unauthorized, invalidInput }

Cont<(), UserError, User> getUser(String id) {
  return fetchUser(id).elseMap((_) => UserError.notFound);
}

getUser(userId)
  .elseUnless((e) => e == UserError.notFound, fallback: User.guest())
  .run((), onThen: display, onElse: showError);
```

---
