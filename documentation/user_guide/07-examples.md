[Home](../../README.md) > User Guide

# Complete Examples & Patterns

This guide provides comprehensive real-world examples that demonstrate Jerelo's capabilities.

## Complete Example: User Management System

Here's a comprehensive example bringing it all together. It uses environment access, fallbacks, background forks, parallel execution, `Cont.bracket` and `Cont.tailRecM`:

```dart
import 'package:jerelo/jerelo.dart';

class AppConfig {
  final String apiUrl;
  final String cacheDir;
  final Duration timeout;

  AppConfig(this.apiUrl, this.cacheDir, this.timeout);
}

// Fetch user with a cache fallback, caching fresh results
Cont<AppConfig, String, User> getUser(String userId) {
  return Cont.askThen<AppConfig, String>()
    .thenDo((config) {
      return fetchFromApi(config.apiUrl, userId, config.timeout);
    })
    .thenDo<User>((user) {
      return user.isValid ? Cont.of(user) : Cont.error('invalid user');
    })
    .elseForkWithEnv((env, error) {
      // Log errors in background
      return logToFile(env.cacheDir, error);
    })
    .elseDo((_) {
      // Fallback to cache
      return Cont.askThen<AppConfig, String>().thenDo((env) {
        return loadFromCache(env.cacheDir, userId);
      });
    })
    .thenForkWithEnv((env, user) {
      // Update cache in background
      return saveToCache(env.cacheDir, user);
    });
}

// Fetch multiple users in parallel
Cont<AppConfig, String, List<User>> getUsers(List<String> userIds) {
  final continuations = userIds.map((id) => getUser(id)).toList();
  return Cont.all(
    continuations,
    policy: OkPolicy.quitFast(),
  );
}

// Process users with resource management
Cont<AppConfig, String, Report> processUsers(List<String> userIds) {
  return Cont.bracket<Database, AppConfig, String, Report>(
    acquire: openDatabase(),
    release: (db) => closeDatabase(db),
    use: (db) {
      // Repeat until the report is complete
      return Cont.tailRecM<AppConfig, String, (), Report>((), (_) {
        return getUsers(userIds)
          .thenDo((users) => processInDb(db, users))
          .thenDo((results) => generateReport(results))
          .thenMap((report) {
            return report.isComplete
              ? TailRec.done(report)
              : TailRec.next(());
          });
      }).thenDo((report) {
        // Notify, then pass the report through
        return Cont.askThen<AppConfig, String>().thenDo((env) {
          return notifyComplete(env.apiUrl, report)
            .thenMap((_) => report);
        });
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

processUsers(['user1', 'user2', 'user3']).run(
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
```

This example demonstrates:
- Environment management (AppConfig)
- Error handling with fallbacks (elseDo)
- Conditional execution (thenDo returning Cont.of or Cont.error)
- Reading config in the middle of a chain (Cont.askThen)
- Background side effects (elseForkWithEnv, thenForkWithEnv)
- Parallel execution with policies (Cont.all with OkPolicy.quitFast)
- Resource management (Cont.bracket)
- Looping (Cont.tailRecM)

---

## Common Patterns

### Pattern 1: Wrapping an Async API

`Cont.fromRun` is the bridge between callback-based code and Jerelo's composition model. Emit exactly one outcome from the async callbacks.

```dart
Cont<E, String, List<Post>> fetchPosts<E>(String authorId) {
  return Cont.fromRun((runtime, observer) {
    http.get(Uri.parse('/posts?author=$authorId')).then(
      (response) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          observer.onThen(data.map(Post.fromJson).toList());
        } else {
          observer.onElse('HTTP ${response.statusCode}');
        }
      },
      onError: (e, _) {
        observer.onElse('$e');
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
      .thenDo((user) => writeToCache(id, user).thenMap((_) => user)),
    )
    .elseDo((_) => Cont.of(User.guest()));
}

getUser<()>(userId).run((), onThen: display, onElse: showError);
```

Execution order: cache → network (write-through on success) → guest fallback.

### Pattern 3: Validation Pipeline

Two strategies, depending on whether you want to stop at the first broken rule or surface every error at once.

**Fail-fast** — `thenDo` short-circuits on the first failure; later rules never run:

```dart
Cont<E, String, UserInput> validateInput<E>(UserInput input) {
  Cont<E, String, UserInput> check(UserInput i, bool passes, String error) =>
    passes ? Cont.of(i) : Cont.error(error);

  return Cont.of<E, String, UserInput>(input)
    .thenDo((i) => check(i, i.email.contains('@'),  'Invalid email'))
    .thenDo((i) => check(i, i.password.length >= 8, 'Password too short'))
    .thenDo((i) => check(i, i.age >= 18,            'Must be 18 or older'));
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

`Cont.all` runs a list of computations concurrently and collects their results. Add a `thenMap` to each task to observe progress as completions arrive. Building the tasks inside `Cont.fromRun` gives every run a fresh counter.

```dart
Cont<(), F, List<T>> withProgress<F, T>(
  List<Cont<(), F, T>> tasks,
  void Function(int done, int total) onProgress,
) {
  return Cont.fromRun((runtime, observer) {
    int done = 0;
    final tracked = tasks.map((task) =>
      task.thenMap((value) {
        onProgress(++done, tasks.length);
        return value;
      })
    ).toList();
    Cont.all(tracked, policy: OkPolicy.quitFast())
      .runWith(runtime, observer);
  });
}

// Usage
withProgress(
  files.map(downloadFile).toList(),
  (done, total) => updateProgressBar(done / total),
).run((), onThen: processAll, onElse: handleError);
```

### Pattern 5: Racing Computations

`Cont.either` runs two computations concurrently and takes the first to succeed. Use it to race a primary source against a fallback. A failure does not end the race: it waits for the other side, and the race fails only if both fail. A crash ends the race immediately.

```dart
// Race remote config against local — whichever succeeds first wins.
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

`Cont.bracket` runs `release` once `use` succeeds, fails, or crashes. It is the correct tool whenever a computation acquires a resource that must be released.

```dart
import 'package:jerelo/jerelo.dart';

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
// (retry is the custom operator from Extending Jerelo)
fetchData()
  .elseMap((error) {
    print('Attempt failed: $error');
    return error;
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
    return env.db
      .query('SELECT * FROM orders WHERE user = ?', [userId])
      .thenDo((orders) {
        return env.logger
          .info('Loaded ${orders.length} orders')
          .thenMap((_) => orders);
      });
  });
}
```

### 3. Use a Bracket for Resource Management

```dart
// Release runs even if use crashes.
Cont<E, F, T> withConnection<E, F, T>(Cont<Connection, F, T> operation) {
  return Cont.bracket(
    acquire: openConnection(),
    release: (conn) => closeConnection(conn),
    use: (conn) => operation.local((_) => conn),
  );
}
```

### 4. Use Typed Errors for Business Logic

```dart
enum UserError { notFound, unauthorized, invalidInput }

Cont<(), UserError, User> getUser(String id) {
  return fetchUser(id).elseMap((_) => UserError.notFound);
}

getUser(userId)
  .elseDo<UserError>((e) {
    return e == UserError.notFound ? Cont.of(User.guest()) : Cont.error(e);
  })
  .run((), onThen: display, onElse: showError);
```

---
