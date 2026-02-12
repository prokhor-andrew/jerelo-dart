[Home](../../README.md) > User Guide

# Environment Management

This guide covers how to manage configuration, dependencies, and context in your computations.

## What is Environment?

Environment allows threading configuration, dependencies, or context through continuation chains without explicitly passing them through every function.

When you compose computations using operators like `thenDo`, `map`, and `elseDo`, you create a chain of operations. However, these operations often need access to shared context like:
- Configuration values (API URLs, timeouts, feature flags)
- Dependencies (database connections, HTTP clients, loggers)
- Runtime context (user sessions, request IDs, auth tokens)

Without environment, you would need to manually pass these values through every single function in your chain, leading to verbose and brittle code.

## Basic Environment Usage

### Accessing Environment

Use `Cont.ask` to retrieve the current environment:

```dart
final program = Cont.ask<Config>().thenDo((config) {
  return fetchFromApi(config.apiUrl);
});

program.run(
  Config(apiUrl: "https://api.example.com"),
  onThen: print,
);
```

### Scoping Environment

Use `scope` to provide an environment value:

```dart
final cont = Cont.ask<String>().thenMap((s) => s.toUpperCase());

final program = cont.scope("hello");

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
final dbOperation = Cont.ask<DatabaseConfig>().thenDo((config) {
  return connectToDb(config.host, config.port);
});

// Run with AppConfig by extracting DatabaseConfig
final program = dbOperation.local<AppConfig>((appConfig) => appConfig.dbConfig);

program.run(
  AppConfig(DatabaseConfig('localhost', 5432), 'key123'),
  onThen: print,
);
```

**Difference from `scope`:**
- `scope(value)`: Replaces environment with a fixed value
- `local(f)`: Transforms the outer environment before passing it down
- `local0(f)`: Provides environment from zero-argument function

**Variants:** `local0`

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
- `thenDoWithEnv`, `thenDoWithEnv0`
- `thenTapWithEnv`, `thenTapWithEnv0`
- `thenZipWithEnv`, `thenZipWithEnv0`
- `thenForkWithEnv`, `thenForkWithEnv0`
- `elseDoWithEnv`, `elseDoWithEnv0`
- `elseTapWithEnv`, `elseTapWithEnv0`
- `elseZipWithEnv`, `elseZipWithEnv0`
- `elseForkWithEnv`, `elseForkWithEnv0`

### Example: Using WithEnv for Configuration

```dart
class ApiConfig {
  final String baseUrl;
  final Duration timeout;
  final String apiKey;

  ApiConfig(this.baseUrl, this.timeout, this.apiKey);
}

Cont<ApiConfig, User> fetchUser(String userId) {
  return Cont.ask<ApiConfig>().thenDoWithEnv((config, _) {
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

Jerelo provides two powerful operators for dependency injection: `injectInto` and `injectedBy`. These enable patterns where the result of one continuation becomes the environment (dependencies) for another.

### Using injectInto

The `injectInto` method takes the value produced by one continuation and injects it as the environment for another continuation:

```dart
// Build a configuration and inject it into operations that need it
final configCont = Cont.of<(), DbConfig>(
  DbConfig(host: 'localhost', port: 5432)
);

// Define an operation that requires DbConfig as its environment
final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// Inject the config into the query operation
final result = configCont.injectInto(queryOp);
// Type: Cont<(), List<User>>

result.run((), onThen: (users) {
  print("Fetched ${users.length} users");
});
```

**Type transformation:**
- Input: `Cont<E, A>` (produces value of type `A`)
- Target: `Cont<A, A2>` (needs environment of type `A`)
- Output: `Cont<E, A2>` (produces value of type `A2` with original environment)

### Using injectedBy

The `injectedBy` method is the inverse - it expresses that a continuation receives its environment from another source. This is equivalent to `cont.injectInto(this)` but reads more naturally:

```dart
// An operation that needs a database config
final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// A provider that produces the config
final configProvider = Cont.of<(), DbConfig>(
  DbConfig(host: 'localhost', port: 5432)
);

// Express that queryOp is injected by configProvider
final result = queryOp.injectedBy(configProvider);
// Type: Cont<(), List<User>>
```

### Dependency Injection Use Cases

These operators are particularly useful for:

#### 1. Resource creation and injection

```dart
// Create a connection pool and inject it into operations
final poolCont = createConnectionPool(maxConnections: 10);

final transaction = Cont.ask<ConnectionPool>()
  .thenDo((pool) => pool.beginTransaction())
  .thenDo((txn) => performDatabaseWork(txn))
  .thenTap((result) => commitTransaction());

final program = poolCont.injectInto(transaction);
```

#### 2. Multi-stage dependency construction

```dart
// Build dependencies in stages
final httpClientCont = Cont.of(HttpClient(timeout: Duration(seconds: 5)));

final authServiceCont = httpClientCont.thenDo((client) {
  return Cont.of(AuthService(client: client, apiKey: 'secret'));
});

final userServiceOp = Cont.ask<AuthService>().thenDo((auth) {
  return fetchAuthenticatedUsers(auth);
});

// Inject the multi-stage dependency
final result = authServiceCont.injectInto(userServiceOp);
```

#### 3. Configuration scoping

```dart
// Different operations with different configs
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
final dbOp = Cont.ask<DatabaseConfig>().thenDo((config) {
  return queryDatabase(config.host, config.port);
});

// Operation needing API config
final apiOp = Cont.ask<ApiConfig>().thenDo((config) {
  return fetchFromApi(config.baseUrl, config.apiKey);
});

// Build and inject different configs
final dbConfig = Cont.of<(), DatabaseConfig>(
  DatabaseConfig('localhost', 5432)
);
final apiConfig = Cont.of<(), ApiConfig>(
  ApiConfig('https://api.example.com', 'key123')
);

// Each operation gets its own config type
final dbResult = dbConfig.injectInto(dbOp);   // Cont<(), DbData>
final apiResult = apiConfig.injectInto(apiOp); // Cont<(), ApiData>

// Combine them
Cont.both(
  dbResult,
  apiResult,
  (dbData, apiData) => merge(dbData, apiData),
  policy: ContBothPolicy.quitFast(),
).run((), onThen: print);
```

#### 4. Testing with mock dependencies

```dart
// Production code
final queryOp = Cont.ask<Database>().thenDo((db) {
  return db.query('SELECT * FROM users');
});

// Production: inject real database
final prodDb = Cont.of(RealDatabase());
final prodProgram = queryOp.injectedBy(prodDb);

// Testing: inject mock database
final mockDb = Cont.of(MockDatabase(testData: [...]));
final testProgram = queryOp.injectedBy(mockDb);
```

## Key Benefits of Environment Management

- **Type-safe**: The compiler ensures environment types match correctly
- **Composable**: Chain multiple injection stages together
- **Flexible**: Use `injectInto` for forward declaration or `injectedBy` for reverse declaration
- **Testable**: Easy to swap implementations by injecting different providers
- **Clean**: No manual passing of dependencies through every function
- **Zero overhead when unused**: If you don't need environment, just use `()` as the unit type
- **Eliminates boilerplate**: No need to pass configuration through every function manually

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
final operation = Cont.ask<OperationConfig>()
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

Cont<RequestContext, Response> handleRequest(Request req) {
  return Cont.ask<RequestContext>()
    .thenDoWithEnv((ctx, _) {
      return logRequest(ctx.requestId, ctx.userId);
    })
    .thenDo((_) => processRequest(req))
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

Cont<Services, User> getUser(String userId) {
  return Cont.ask<Services>().thenDoWithEnv((services, _) {
    return services.cache.get(userId).elseDo((_) {
      return services.database.query('SELECT * FROM users WHERE id = ?', [userId])
        .thenTap((user) => services.cache.set(userId, user))
        .thenTapWithEnv((services, user) {
          return services.logger.info('Fetched user $userId');
        });
    });
  });
}
```

---

## Next Steps

Now that you understand environment management, continue to:
- **[Extending Jerelo](06-extending.md)** - Create custom operators and computations
- **[Complete Examples](07-examples.md)** - See comprehensive real-world patterns
- **[API Reference](../api_reference/)** - Quick reference lookup
