[Home](../../README.md) > User Guide

# Environment Management

This guide covers how to manage configuration, dependencies, and context in your computations.

## What is Environment?

Environment allows threading configuration, dependencies, or context through continuation chains without explicitly passing them through every function.

When you compose computations using operators like `thenDo`, `thenMap`, and `elseDo`, you create a chain of operations. However, these operations often need access to shared context like:
- Configuration values (API URLs, timeouts, feature flags)
- Dependencies (database connections, HTTP clients, loggers)
- Runtime context (user sessions, request IDs, auth tokens)

Without environment, you would need to manually pass these values through every single function in your chain, leading to verbose and brittle code.

## Basic Environment Usage

### Accessing Environment

Use `Cont.askThen` to retrieve the current environment on the success channel:

```dart
final program = Cont.askThen<Config, String>().thenDo((config) {
  return fetchFromApi(config.apiUrl);
});

program.run(
  Config(apiUrl: "https://api.example.com"),
);
```

Use `Cont.askElse` to retrieve the current environment on the else (error) channel:

```dart
final program = Cont.askElse<Config, int>().elseDo((config) { 
  return fetchFromCache(config.cacheDir);
});

program.run(
  Config(cacheDir: "..."),
);
```

### Providing Environment with withEnv

Use `withEnv` to provide a fixed environment value:

```dart
final cont = Cont.askThen<String, Never>().thenMap((s) => s.toUpperCase());

final program = cont.withEnv("hello");

program.run(
  "ignored", // outer env doesn't matter
  onThen: print,
); // prints: HELLO
```

### Transforming Environment with local

The `local` operator lets you transform the environment before passing it to a continuation. This is useful when you need to adapt the environment type or modify its contents:

```dart
class DatabaseConfig {
  final String host;
  final int port;
  DatabaseConfig(this.host, this.port);
}

class AppConfig {
  final DatabaseConfig dbConfig;
  final String apiKey;
  AppConfig(this.dbConfig, this.apiKey);
}

// Operation that needs DatabaseConfig
final dbOperation = Cont.askThen<DatabaseConfig, String>().thenDo((config) {
  return connectToDb(config.host, config.port);
});

// Run with AppConfig by extracting DatabaseConfig
final program = dbOperation.local<AppConfig>((appConfig) => appConfig.dbConfig);

program.run(
  AppConfig(DatabaseConfig('localhost', 5432), 'key123'),
  onThen: print,
);
```

**Difference from `withEnv`:**
- `withEnv(value)`: Replaces environment with a fixed value
- `local(f)`: Transforms the outer environment before passing it down
- `local0(f)`: Provides environment from zero-argument function

**Use cases:**
- Adapting environment types (extracting sub-configurations)
- Adding context to environment (timestamps, request IDs)
- Environment middleware patterns

## WithEnv Variants

All chaining and error handling operators have `WithEnv` variants that provide access to the environment:

```dart
Cont.of(42).thenDoWithEnv((env, value) {
  return fetchWithConfig(env.apiUrl, value);
});
```

Available variants:

**Transformations:**
- `thenMapWithEnv`, `thenMapWithEnv0`
- `elseMapWithEnv`, `elseMapWithEnv0`

**Chaining:**
- `thenDoWithEnv`, `thenDoWithEnv0`
- `elseDoWithEnv`, `elseDoWithEnv0`
- `crashDoWithEnv`, `crashDoWithEnv0`

**Tapping:**
- `thenTapWithEnv`, `thenTapWithEnv0`
- `elseTapWithEnv`, `elseTapWithEnv0`
- `crashTapWithEnv`, `crashTapWithEnv0`

**Combining:**
- `thenZipWithEnv`, `thenZipWithEnv0`
- `elseZipWithEnv`, `elseZipWithEnv0`
- `crashZipWithEnv`, `crashZipWithEnv0`

**Forking:**
- `thenForkWithEnv`, `thenForkWithEnv0`
- `elseForkWithEnv`, `elseForkWithEnv0`
- `crashForkWithEnv`, `crashForkWithEnv0`

**Conditions:**
- `thenIfWithEnv`, `thenIfWithEnv0`
- `elseUnlessWithEnv`, `elseUnlessWithEnv0`
- `crashUnlessThenWithEnv`, `crashUnlessThenWithEnv0`
- `crashUnlessElseWithEnv`, `crashUnlessElseWithEnv0`

**Loops:**
- `thenWhileWithEnv`, `thenWhileWithEnv0`
- `thenUntilWithEnv`, `thenUntilWithEnv0`
- `elseWhileWithEnv`, `elseWhileWithEnv0`
- `elseUntilWithEnv`, `elseUntilWithEnv0`
- `crashWhileWithEnv`, `crashWhileWithEnv0`
- `crashUntilWithEnv`, `crashUntilWithEnv0`

**Demotion and promotion:**
- `demoteWithEnv`, `demoteWithEnv0`
- `promoteWithEnv`, `promoteWithEnv0`

**Crash recovery:**
- `crashRecoverThenWithEnv`, `crashRecoverThenWithEnv0`
- `crashRecoverElseWithEnv`, `crashRecoverElseWithEnv0`

### Example: Using WithEnv for Configuration

```dart
class ApiConfig {
  final String baseUrl;
  final Duration timeout;
  final String apiKey;

  ApiConfig(this.baseUrl, this.timeout, this.apiKey);
}

Cont<ApiConfig, String, User> fetchUser(String userId) {
  return Cont.askThen<ApiConfig, String>().thenDo((config) {
    return httpGet(
      '${config.baseUrl}/users/$userId',
      headers: {'Authorization': 'Bearer ${config.apiKey}'},
      timeout: config.timeout,
    );
  }).thenMap((response) => User.fromJson(response));
}

// Usage
final config = ApiConfig(
  'https://api.example.com',
  Duration(seconds: 5),
  'secret-key',
);

fetchUser('123').run(config, onThen: print);
```

## Dependency Injection Patterns

Jerelo provides operators for dependency injection where the result of one continuation becomes the environment for another.

### Using thenInject

The `thenInject` method takes the success value of this continuation and injects it as the environment for another continuation:

```dart
// Build a configuration and inject it into operations that need it
final configCont = Cont.of<(), Never, DbConfig>(
  DbConfig(host: 'localhost', port: 5432)
);

// Define an operation that requires DbConfig as its environment
final queryOp = Cont.askThen<DbConfig, String>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// Inject the config into the query operation
final result = configCont.thenInject(queryOp);
// Type: Cont<(), String, List<User>>

result.run((), onThen: (users) {
  print("Fetched ${users.length} users");
});
```

**Type transformation:**
- Input: `Cont<E, F, A>` (produces value of type `A`)
- Target: `Cont<A, F, A2>` (needs environment of type `A`)
- Output: `Cont<E, F, A2>` (produces value of type `A2` with original environment)

We kinda "glue" `A`s together in `Cont<E, _, A>` and `Cont<A, _, A2>` and get 
`Cont<E, _, A2>` ("_" is just to show that it can be anything).

### Using injectedByThen

The `injectedByThen` method is the inverse — it expresses that a continuation receives its environment from another source:

```dart
// An operation that needs a database config
final queryOp = Cont.askThen<DbConfig, String>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// A provider that produces the config
final configProvider = Cont.of<(), String, DbConfig>(
  DbConfig(host: 'localhost', port: 5432)
);

// Express that queryOp is injected by configProvider
final result = queryOp.injectedByThen(configProvider);
// Type: Cont<(), String, List<User>>
```

### Error-Channel Injection

You can also inject via the error channel:

- `elseInject(cont)`: When this continuation terminates on the else channel with error `F`, runs `cont` using `F` as its environment
- `injectedByElse(cont)`: This continuation receives its environment from the else channel of `cont`

```dart
// An error recovery operation that needs the error as its environment
final recoveryOp = Cont.askThen<String, String>().thenDo((errorMsg) {
  return logAndRecover(errorMsg);
});

// If mainOp fails, inject the error into recoveryOp
final result = mainOp.elseInject(recoveryOp);
```

### Dependency Injection Use Cases

#### 1. Resource creation and injection

```dart
// Create a connection pool and inject it into operations
final poolCont = createConnectionPool(maxConnections: 10);

final transaction = Cont.askThen<ConnectionPool, String>()
  .thenDo((pool) => pool.beginTransaction())
  .thenDo((txn) => performDatabaseWork(txn))
  .thenTap((result) => commitTransaction());

final program = poolCont.thenInject(transaction);
```

#### 2. Multi-stage dependency construction

```dart
// Build dependencies in stages
final httpClientCont = Cont.of(HttpClient(timeout: Duration(seconds: 5)));

final authServiceCont = httpClientCont.thenDo((client) {
  return Cont.of(AuthService(client: client, apiKey: 'secret'));
});

final userServiceOp = Cont.askThen<AuthService, String>().thenDo((auth) {
  return fetchAuthenticatedUsers(auth);
});

// Inject the multi-stage dependency
final result = authServiceCont.thenInject(userServiceOp);
```

#### 3. Configuration scoping

```dart
class DatabaseConfig {
  final String host;
  final int port;
  DatabaseConfig(this.host, this.port);
}

class ApiConfig {
  final String baseUrl;
  final String apiKey;
  ApiConfig(this.baseUrl, this.apiKey);
}

// Operation needing DB config
final dbOp = Cont.askThen<DatabaseConfig, String>().thenDo((config) {
  return queryDatabase(config.host, config.port);
});

// Operation needing API config
final apiOp = Cont.askThen<ApiConfig, String>().thenDo((config) {
  return fetchFromApi(config.baseUrl, config.apiKey);
});

// Build and inject different configs
final dbConfig = Cont.of<void, String, DatabaseConfig>(
  DatabaseConfig('localhost', 5432)
);
final apiConfig = Cont.of<void, String, ApiConfig>(
  ApiConfig('https://api.example.com', 'key123')
);

// Each operation gets its own config type
final dbResult = dbConfig.thenInject(dbOp);
final apiResult = apiConfig.thenInject(apiOp);

// Combine them
Cont.both(
  dbResult,
  apiResult,
  (dbData, apiData) => merge(dbData, apiData),
  policy: OkPolicy.quitFast<String>(),
).run((), onThen: print);
```

#### 4. Testing with mock dependencies

```dart
// Production code
final queryOp = Cont.askThen<Database, String>().thenDo((db) {
  return db.query('SELECT * FROM users');
});

// Production: inject real database
final prodDb = Cont.of(RealDatabase());
final prodProgram = queryOp.injectedByThen(prodDb);

// Testing: inject mock database
final mockDb = Cont.of(MockDatabase(testData: [...]));
final testProgram = queryOp.injectedByThen(mockDb);
```

## Key Benefits of Environment Management

- **Type-safe**: The compiler ensures environment types match correctly
- **Composable**: Chain multiple injection stages together
- **Flexible**: Use `thenInject` for forward declaration or `injectedByThen` for reverse declaration
- **Testable**: Easy to swap implementations by injecting different providers
- **Clean**: No manual passing of dependencies through every function
- **Zero overhead when unused**: If you don't need environment, just use `void` as the type

## Common Patterns

### Pattern 1: Layered Configuration

```dart
// Layer 1: App-wide config
class AppConfig {
  final String environment;
  final bool debugMode;
}

// Layer 2: Feature-specific config
class FeatureConfig {
  final AppConfig appConfig;
  final String featureFlag;
}

// Layer 3: Operation-specific config
class OperationConfig {
  final FeatureConfig featureConfig;
  final int retryCount;
}

// Extract what you need at each level
final operation = Cont.askThen<OperationConfig, String>()
  .local<FeatureConfig>((fc) => OperationConfig(fc, 3))
  .local<AppConfig>((ac) => FeatureConfig(ac, 'newFeature'));
```

### Pattern 2: Request Context Threading

```dart
class RequestContext {
  final String requestId;
  final String userId;
  final DateTime timestamp;
}

Cont<RequestContext, String, Response> handleRequest(Request req) {
  return Cont.askThen<RequestContext, String>()
    .thenDo((ctx) {
      return logRequest(ctx.requestId, ctx.userId);
    })
    .thenDo0(() => processRequest(req))
    .thenTapWithEnv((ctx, response) {
      return logResponse(ctx.requestId, response);
    });
}

// Usage
final ctx = RequestContext(
  requestId: generateId(),
  userId: extractUserId(request),
  timestamp: DateTime.now(),
);

handleRequest(request).run(ctx, onThen: sendResponse);
```

### Pattern 3: Service Locator Pattern

```dart
class Services {
  final Logger logger;
  final Database database;
  final Cache cache;
  final HttpClient httpClient;
}

Cont<Services, String, User> getUser(String userId) {
  return Cont.askThen<Services, String>().thenDo((services) {
    final cached = services.cache.get<User>(userId);
    if (cached != null) {
      return Cont.of(cached);
    } else {
      return Cont.error('cache miss');
    };
  }).elseDoWithEnv0((services) {
    return services.database.query('SELECT * FROM users WHERE id = ?', [userId]);
  });
}
```

---

## Next Steps

Now that you understand environment management, continue to:
- **[Extending Jerelo](06-extending.md)** - Create custom operators and computations
- **[Complete Examples](07-examples.md)** - See comprehensive real-world patterns
