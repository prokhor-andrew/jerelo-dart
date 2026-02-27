# Jerelo

**Jerelo** is a Dart library for building cold, lazy, reusable computations using continuation-passing style. It provides a composable `Cont` type with three outcome channels — success, typed errors, and crashes — plus operations for chaining, transforming, branching, merging, and error handling.

The name "Jerelo" is Ukrainian for "source" or "spring" - each `Cont` is a source of results that can branch, merge, filter, and transform data through your workflows.

## What Makes Jerelo Different?

Unlike Dart's `Future` which starts executing immediately upon creation, `Cont` is:

- **Cold**: Doesn't run until you explicitly call `run`
- **Pure**: No side effects during construction
- **Lazy**: Evaluation is deferred
- **Reusable**: Can be safely executed multiple times with different configurations
- **Composable**: Build complex flows from simple, testable pieces

This makes `Cont` ideal for defining complex business logic that needs to be tested, reused across different contexts, or configured at runtime.

## Quick Example

```dart
import 'package:jerelo/jerelo.dart';

// Define a computation (doesn't execute yet)
final getUserData = Cont.of<AppConfig, String, String>(userId)
  .thenDo((id) => fetchUserFromApi(id))
  .thenIf((user) => user.isActive, fallback: 'User is inactive')
  .elseDo((_) => loadUserFromCache(userId))
  .thenTap((user) => logAccess(user));

// Execute it multiple times with different configs
getUserData.run(prodConfig, onElse: handleError, onThen: handleSuccess);
getUserData.run(testConfig, onElse: handleError, onThen: handleSuccess);
```

## What is Cont?

```dart
final class Cont<E, F, A>
```

A continuation monad representing a computation that will eventually produce a value of type `A`, terminate with a typed error of type `F`, or crash with an unexpected exception.

**Type Parameters:**
- `E`: The environment type providing context for the continuation execution
- `F`: The error type for expected, typed failures on the else channel
- `A`: The value type that the continuation produces upon success

---

## Design Goals

- **Pure Dart** - No platform dependencies
- **Zero dependencies** - Minimal footprint
- **Minimal API** - Learn once, use everywhere
- **Modular boundaries** - Swap HTTP/DB/cache/logging without rewriting flows
- **Execution agnostic** - Same flow works sync, async, and in tests
- **Explicit failures** - Unexpected throws become explicit termination
- **Extensible** - Core stays stable, extras stay optional

## Documentation

### User Guide

A comprehensive guide to understanding and using Jerelo:

1. [Introduction & Core Concepts](documentation/user_guide/01-introduction.md) - Understanding computations and continuation-passing style
2. [Fundamentals: Construct & Run](documentation/user_guide/02-fundamentals.md) - Learn to create and execute computations
3. [Composing Computations](documentation/user_guide/03-composing-computations.md) - Master mapping, chaining, branching, and error handling
4. [Racing and Merging](documentation/user_guide/04-racing-and-merging.md) - Parallel execution, racing, and complex workflows
5. [Environment Management](documentation/user_guide/05-environment.md) - Configuration and dependency injection patterns
6. [Extending Jerelo](documentation/user_guide/06-extending.md) - Create custom operators and computations
7. [Complete Examples](documentation/user_guide/07-examples.md) - Real-world patterns and use cases

### API Reference

Complete reference for all public APIs:

- **[Types](documentation/api_reference/types.md)** - ContCrash, CrashOr, ContRuntime, ContObserver, ContCancelToken
- **[Construction](documentation/api_reference/construction.md)** - Creating continuations with constructors and decorators
- **[Execution](documentation/api_reference/execution.md)** - Running continuations: run, runWith, extensions
- **[Then Channel](documentation/api_reference/then.md)** - Success path operations: mapping, chaining, tapping, zipping, forking, demotion, loops, conditionals
- **[Else Channel](documentation/api_reference/else.md)** - Error path operations: fallback, promotion, transformation, error handling
- **[Crash Channel](documentation/api_reference/crash.md)** - Crash recovery operations: recovery, side effects, conditionals, retry loops
- **[Combining](documentation/api_reference/combining.md)** - Parallel execution: OkPolicy, CrashPolicy, both, all, either, any, coalesce, converge
- **[Environment](documentation/api_reference/env.md)** - Environment management: local, withEnv, injection

## Full Example

Here's a complete example demonstrating key Jerelo features:

```dart
import 'dart:async';
import 'package:jerelo/jerelo.dart';

// Configuration injected as environment
class AppConfig {
  final String apiUrl;
  final Duration timeout;
  final bool enableCache;

  AppConfig(this.apiUrl, this.timeout, this.enableCache);
}

// Domain model
class User {
  final String id;
  final String name;
  final bool isActive;

  User(this.id, this.name, this.isActive);
}

// Simulated API call
Cont<AppConfig, String, User> fetchUserFromApi(String userId) {
  return Cont.askThen<AppConfig, String>().thenDo((config) {
    return Cont.fromRun((runtime, observer) {
      // Simulate async API call
      Future.delayed(config.timeout, () {
        if (runtime.isCancelled()) return;

        // Simulate successful response
        observer.onThen(User(userId, 'John Doe', true));
      });
    });
  });
}

// Simulated cache fallback
Cont<AppConfig, String, User> loadUserFromCache(String userId) {
  return Cont.of(User(userId, 'Cached User', true));
}

// Simulated logging side effect
Cont<AppConfig, String, void> logAccess(User user) {
  return Cont.fromRun((runtime, observer) {
    print('[LOG] User accessed: ${user.name}');
    observer.onThen(null);
  });
}

// Build a computation pipeline
Cont<AppConfig, String, User> getUserData(String userId) {
  return fetchUserFromApi(userId)
    // Filter: only proceed if user is active, with custom error
    .thenIf(
      (user) => user.isActive,
      fallback: 'User account is not active',
    )
    // Fallback: if API fails or user inactive, try cache
    .elseDoWithEnv((config, error) {
      return config.enableCache
        ? loadUserFromCache(userId)
        : Cont.error(error);
    })
    // Side effect: log access without altering the value
    .thenTap((user) => logAccess(user))
    // Recover unexpected exceptions into typed errors
    .crashRecoverElse((crash) => 'Unexpected error: $crash');
}

// Fetch multiple users in parallel
Cont<AppConfig, String, List<User>> getMultipleUsers(List<String> userIds) {
  final computations = userIds.map(getUserData).toList();

  return Cont.all(
    computations,
    policy: OkPolicy.quitFast(), // Fail fast on first error
  );
}

void main() {
  // Production configuration
  final prodConfig = AppConfig(
    'https://api.example.com',
    Duration(seconds: 5),
    true,
  );

  // Test configuration
  final testConfig = AppConfig(
    'http://localhost:3000',
    Duration(milliseconds: 100),
    false,
  );

  print('=== Single User Example ===');

  // Define the computation once
  final singleUserFlow = getUserData('user123');

  // Execute with production config — run returns a ContCancelToken
  final token1 = singleUserFlow.run(
    prodConfig,
    onCrash: (crash) => print('Production crash: $crash'),
    onElse: (error) => print('Production failed: $error'),
    onThen: (user) => print('Production success: ${user.name}'),
  );

  // Execute the same computation with test config
  final token2 = singleUserFlow.run(
    testConfig,
    onElse: (error) => print('Test failed: $error'),
    onThen: (user) => print('Test success: ${user.name}'),
  );

  print('\n=== Multiple Users Example ===');

  // Fetch multiple users in parallel
  final multiUserFlow = getMultipleUsers(['user1', 'user2', 'user3']);

  multiUserFlow.run(
    prodConfig,
    onElse: (error) => print('Failed to fetch users: $error'),
    onThen: (users) => print('Fetched ${users.length} users: ${users.map((u) => u.name).join(', ')}'),
  );

  print('\n=== Advanced: Racing API vs Cache ===');

  // Race API against cache, return whichever completes first
  final racingFlow = Cont.either(
    fetchUserFromApi('user456'),
    loadUserFromCache('user456'),
    (e1, e2) => '$e1; $e2', // Combine errors if both fail
    policy: OkPolicy.quitFast(), // Return first success
  );

  racingFlow.run(
    prodConfig,
    onElse: (error) => print('Both sources failed: $error'),
    onThen: (user) => print('Got user from fastest source: ${user.name}'),
  );

  // Cancel any running computation when needed
  // token1.cancel();
  // token2.cancel();
}
```

## Key Features Demonstrated

The example above showcases:

- **Three-channel design**: Success (then), typed errors (else), and crashes for unexpected exceptions
- **Environment Management**: Configuration threaded through computations via `AppConfig`
- **Chaining**: Sequential operations with `thenDo`, `elseDoWithEnv`
- **Error Handling**: Fallbacks with `elseDo`, conditional caching with `elseDoWithEnv`
- **Crash Recovery**: Converting unexpected exceptions into typed errors with `crashRecoverElse`
- **Conditional Logic**: Filtering with `thenIf` and typed `fallback` errors
- **Side Effects**: Logging with `thenTap` while preserving the original value
- **Parallel Execution**: Multiple computations with `Cont.all` and `OkPolicy`
- **Racing**: Competing computations with `Cont.either` and error combining
- **Reusability**: Same computation executed with different configurations
- **Cancellation**: Cooperative cancellation via `ContCancelToken` returned by `run`

## License

See [LICENSE](LICENSE) file for details.