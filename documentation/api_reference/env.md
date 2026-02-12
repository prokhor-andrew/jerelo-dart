[Home](../../README.md) > API Reference

# Environment Management

Managing contextual information and dependencies through continuations.

---

## Table of Contents

- [Reading Environment](#reading-environment)
  - [Cont.ask](#contask)
- [Transforming Environment](#transforming-environment)
  - [local](#local)
  - [local0](#local0)
  - [scope](#scope)
- [Environment Injection](#environment-injection)
  - [injectInto](#injectinto)
  - [injectedBy](#injectedby)

---

## Reading Environment

### Cont.ask

```dart
static Cont<E, E> ask<E>()
```

Retrieves the current environment value.

Accesses the environment of type `E` from the runtime context. This is used to read configuration, dependencies, or any contextual information that flows through the continuation execution.

Returns a continuation that succeeds with the environment value.

**Example:**
```dart
final cont = Cont.ask<DatabaseConfig>().thenDo((config) {
  return queryDatabase(config.connectionString);
});

// Use in computations
final fetchUser = Cont.ask<AppEnv>().thenDo((env) {
  return http.get('${env.apiUrl}/users/$userId');
});
```

---

## Transforming Environment

### local

```dart
Cont<E2, A> local<E2>(E Function(E2) f)
```

Runs this continuation with a transformed environment.

Transforms the environment from `E2` to `E` using the provided function, then executes this continuation with the transformed environment. This allows adapting the continuation to work in a context with a different environment type.

- **Parameters:**
  - `f`: Function that transforms the outer environment to the inner environment

**Example:**
```dart
// Continuation needs DatabaseConfig
final query = queryUsers();

// But we have AppConfig containing DatabaseConfig
final adapted = query.local<AppConfig>((appConfig) => appConfig.database);

// Now can run with AppConfig
adapted.run(appConfig, onThen: print);
```

---

### local0

```dart
Cont<E2, A> local0<E2>(E Function() f)
```

Runs this continuation with a new environment from a zero-argument function.

Similar to `local` but obtains the environment from a zero-argument function instead of transforming the existing environment.

- **Parameters:**
  - `f`: Zero-argument function that provides the new environment

**Example:**
```dart
final query = queryUsers();

// Provide a fixed config
final withConfig = query.local0(() => DatabaseConfig('localhost', 5432));

// Can now run with any environment type
withConfig.run((), onThen: print);
```

---

### scope

```dart
Cont<E2, A> scope<E2>(E value)
```

Runs this continuation with a fixed environment value.

Replaces the environment context with the provided value for the execution of this continuation. This is useful for providing configuration, dependencies, or context to a continuation.

- **Parameters:**
  - `value`: The environment value to use

**Example:**
```dart
final query = queryUsers();

// Run with a specific config
final scoped = query.scope(DatabaseConfig('localhost', 5432));

// The environment is now fixed
scoped.run((), onThen: print);
```

---

## Environment Injection

### injectInto

```dart
Cont<E, A2> injectInto<A2>(Cont<A, A2> cont)
```

Injects the value produced by this continuation as the environment for another continuation.

This method enables dependency injection patterns where the result of one continuation becomes the environment (context) for another. It sequences this continuation with `cont`, passing the produced value as `cont`'s environment.

The transformation changes the environment type from `E` to `A`, and the value type from `A` to `A2`. This is useful when you want to:
- Build a configuration/dependency and run operations with it
- Create resources and inject them into computations that need them
- Chain operations where output becomes context for the next stage

- **Type Parameters:**
  - `A2`: The value type produced by the target continuation

- **Parameters:**
  - `cont`: The continuation that will receive this continuation's value as its environment

**Returns:** A continuation that:
1. Executes this continuation to produce a value of type `A`
2. Uses that value as the environment for `cont`
3. Produces `cont`'s result of type `A2`

**Example:**
```dart
// Create a database configuration
final configCont = Cont.of<(), DbConfig>(DbConfig('localhost', 5432));

// Define an operation that needs the config as environment
final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// Inject the config into the query operation
final result = configCont.injectInto(queryOp);
// Type: Cont<(), List<User>>

result.run((), onThen: print);
```

---

### injectedBy

```dart
Cont<E0, A> injectedBy<E0>(Cont<E0, E> cont)
```

Receives the environment for this continuation from another continuation's value.

This method is the inverse of `injectInto`. It allows this continuation to obtain its required environment from the result of another continuation. The outer continuation `cont` produces a value of type `E` which becomes the environment for this continuation.

This is equivalent to `cont.injectInto(this)` but provides a more intuitive syntax when you want to express that this continuation is being supplied with dependencies from another source.

- **Type Parameters:**
  - `E0`: The environment type of the outer continuation

- **Parameters:**
  - `cont`: The continuation that produces the environment value this continuation needs

**Returns:** A continuation that:
1. Executes `cont` to produce a value of type `E`
2. Uses that value as the environment for this continuation
3. Produces this continuation's result of type `A`

**Example:**
```dart
// Define an operation that needs a database config
final queryOp = Cont.ask<DbConfig>().thenDo((config) {
  return executeQuery(config, 'SELECT * FROM users');
});

// Create a continuation that produces the config
final configProvider = Cont.of<(), DbConfig>(DbConfig('localhost', 5432));

// Express that queryOp receives its environment from configProvider
final result = queryOp.injectedBy(configProvider);
// Type: Cont<(), List<User>>

result.run((), onThen: print);
```

---

## Usage Patterns

### Dependency Injection

```dart
// Define services that need dependencies
class UserService {
  Cont<Database, User> getUser(int id) {
    return Cont.ask<Database>().thenDo((db) {
      return db.query('SELECT * FROM users WHERE id = ?', [id]);
    });
  }
}

// Build the dependency
final dbCont = Cont.of<(), Database>(Database('localhost'));

// Inject it into the service operation
final service = UserService();
final result = dbCont.injectInto(service.getUser(123));

result.run((), onThen: print);
```

### Environment Transformation

```dart
// Extract a specific part of the environment
final result = operation
  .local<FullConfig>((config) => config.database);

// Transform environment type
final adapted = operation
  .local<Map<String, dynamic>>((json) => Config.fromJson(json));
```

### Multi-Layer Configuration

```dart
// Layer 1: App config
final appConfigCont = loadAppConfig();

// Layer 2: Extract DB config and run DB operations
final dbOperation = Cont.ask<DbConfig>().thenDo((db) => queryUsers(db));

// Layer 3: Inject DB config from app config
final result = appConfigCont.thenDo((appConfig) {
  return dbOperation.scope(appConfig.database);
});
```
