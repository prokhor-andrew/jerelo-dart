# Jerelo

**Jerelo** is a Dart library for building cold, lazy, reusable computations using continuation-passing style. It provides a composable `Cont` type with operations for chaining, transforming, branching, merging, and error handling.

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
final getUserData = Cont.of(userId)
  .thenDo((id) => fetchUserFromApi(id))
  .thenIf((user) => user.isActive)
  .elseDo((_) => loadUserFromCache(userId))
  .thenTap((user) => logAccess(user));

// Execute it multiple times with different configs
getUserData.run(prodConfig, onElse: handleError, onThen: handleSuccess);
getUserData.run(testConfig, onElse: handleError, onThen: handleSuccess);
```

## Design Goals

- **Pure Dart** - No platform dependencies
- **Zero dependencies** - Minimal footprint
- **Minimal API** - Learn once, use everywhere
- **Modular boundaries** - Swap HTTP/DB/cache/logging without rewriting flows
- **Execution agnostic** - Same flow works sync, async, and in tests
- **Explicit failures** - Unexpected throws become explicit termination
- **Extensible** - Core stays stable, extras stay optional

## Documentation

- **[Documentation Home](documentation/README.md)** - Complete documentation hub
- **[User Guide](documentation/user_guide/01-introduction.md)** - Start learning Jerelo
- **[API Reference](documentation/api/)** - Complete API documentation for all types and methods

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
Cont<AppConfig, User> fetchUserFromApi(String userId) {
  return Cont.ask<AppConfig>().thenDo((config) {
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
Cont<AppConfig, User> loadUserFromCache(String userId) {
  return Cont.of(User(userId, 'Cached User', true));
}

// Simulated logging side effect
Cont<AppConfig, void> logAccess(User user) {
  return Cont.fromRun((runtime, observer) {
    print('[LOG] User accessed: ${user.name}');
    observer.onThen(null);
  });
}

// Simulated error logging
Cont<AppConfig, void> logError(List<ContError> errors) {
  return Cont.fromRun((runtime, observer) {
    print('[ERROR] Failed with ${errors.length} error(s)');
    for (final e in errors) {
      print('  - ${e.error}');
    }
    observer.onThen(null);
  });
}

// Build a computation pipeline
Cont<AppConfig, User> getUserData(String userId) {
  return fetchUserFromApi(userId)
    // Filter: only proceed if user is active
    .thenIf((user) => user.isActive)
    // Fallback: if API fails or user inactive, try cache
    .elseDoWithEnv((config, errors) {
      return config.enableCache
        ? loadUserFromCache(userId)
        : Cont.stop(errors);
    })
    // Side effect: log access without blocking
    .thenTap((user) => logAccess(user))
    // Error logging
    .elseTap((errors) => logError(errors));
}

// Fetch multiple users in parallel
Cont<AppConfig, List<User>> getMultipleUsers(List<String> userIds) {
  final computations = userIds.map(getUserData).toList();

  return Cont.all(
    computations,
    policy: ContBothPolicy.quitFast(), // Fail fast on first error
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
    onElse: (errors) => print('Production failed: ${errors.length} error(s)'),
    onThen: (user) => print('Production success: ${user.name}'),
  );

  // Execute the same computation with test config
  final token2 = singleUserFlow.run(
    testConfig,
    onElse: (errors) => print('Test failed: ${errors.length} error(s)'),
    onThen: (user) => print('Test success: ${user.name}'),
  );

  print('\n=== Multiple Users Example ===');

  // Fetch multiple users in parallel
  final multiUserFlow = getMultipleUsers(['user1', 'user2', 'user3']);

  multiUserFlow.run(
    prodConfig,
    onElse: (errors) => print('Failed to fetch users'),
    onThen: (users) => print('Fetched ${users.length} users: ${users.map((u) => u.name).join(', ')}'),
  );

  print('\n=== Advanced: Racing API vs Cache ===');

  // Race API against cache, return whichever completes first
  final racingFlow = Cont.either(
    fetchUserFromApi('user456'),
    loadUserFromCache('user456'),
    policy: ContEitherPolicy.quitFast(), // Return first success
  );

  racingFlow.run(
    prodConfig,
    onElse: (errors) => print('Both sources failed'),
    onThen: (user) => print('Got user from fastest source: ${user.name}'),
  );

  // Cancel any running computation when needed
  // token1.cancel();
  // token2.cancel();
}
```

## Key Features Demonstrated

The example above showcases:

- **Environment Management**: Configuration threaded through computations via `AppConfig`
- **Chaining**: Sequential operations with `thenDo`, `thenDoWithEnv`
- **Error Handling**: Fallbacks with `elseDo`, error logging with `elseTap`
- **Conditional Logic**: Filtering with `thenIf`
- **Side Effects**: Non-blocking logging with `thenTap`
- **Parallel Execution**: Multiple computations with `Cont.all` and `ContBothPolicy`
- **Racing**: Competing computations with `Cont.either` and `ContEitherPolicy`
- **Reusability**: Same computation executed with different configurations
- **Cancellation**: Cooperative cancellation via `ContCancelToken` returned by `run`

## Learn More

- Explore the [Documentation](documentation/README.md) for comprehensive guides and references
- Start with the [User Guide](documentation/user_guide/01-introduction.md) for in-depth explanations and patterns
- Check the [API Reference](documentation/api/) for complete method documentation
- See [Real-World Examples](documentation/user_guide/07-examples.md) for practical patterns

## License

See [LICENSE](LICENSE) file for details.