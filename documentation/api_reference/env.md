[Home](../../README.md) > API Reference > Environment Management

# Environment Management

Managing contextual information and dependencies through continuations.

---

## Table of Contents

- [Transforming Environment](#transforming-environment)
  - [local](#local)
  - [local0](#local0)
  - [withEnv](#withenv)
- [Then-Channel Injection](#then-channel-injection)
  - [thenInject](#theninject)
  - [injectedByThen](#injectedbythen)
- [Else-Channel Injection](#else-channel-injection)
  - [elseInject](#elseinject)
  - [injectedByElse](#injectedbyelse)

---

## Transforming Environment

### local

```dart
Cont<E2, F, A> local<E2>(E Function(E2) f)
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
Cont<E2, F, A> local0<E2>(E Function() f)
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

### withEnv

```dart
Cont<E2, F, A> withEnv<E2>(E value)
```

Runs this continuation with a fixed environment value.

Replaces the environment context with the provided value for the execution of this continuation.

- **Parameters:**
  - `value`: The environment value to use

**Example:**
```dart
final query = queryUsers();

// Run with a specific config
final scoped = query.withEnv(DatabaseConfig('localhost', 5432));

// The environment is now fixed
scoped.run((), onThen: print);
```

---

## Then-Channel Injection

### thenInject

```dart
Cont<E, F, A2> thenInject<A2>(Cont<A, F, A2> cont)
```

Injects the successful value of this continuation as the environment for another continuation.

This method enables dependency injection patterns where the result of one continuation becomes the environment (context) for another. It sequences this continuation with `cont`, passing the produced value as `cont`'s environment.

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
final configCont = Cont.of<(), Never, DbConfig>(DbConfig('localhost', 5432));

// Define an operation that needs the config as environment
final queryOp = Cont.askThen<DbConfig, String>()
  .thenDo((config) => executeQuery(config, 'SELECT * FROM users'));

// Inject the config into the query operation
final result = configCont.thenInject(queryOp);
// Type: Cont<(), Never, List<User>>

result.run((), onThen: print);
```

---

### injectedByThen

```dart
Cont<E0, F, A> injectedByThen<E0>(Cont<E0, F, E> cont)
```

Receives the environment for this continuation from another continuation's successful value.

This is the inverse of `thenInject`. The outer continuation `cont` produces a value of type `E` which becomes the environment for this continuation.

Equivalent to `cont.thenInject(this)`.

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
final queryOp = Cont.askThen<DbConfig, String>()
  .thenDo((config) => executeQuery(config, 'SELECT * FROM users'));

// Create a continuation that produces the config
final configProvider = Cont.of<(), Never, DbConfig>(DbConfig('localhost', 5432));

// Express that queryOp receives its environment from configProvider
final result = queryOp.injectedByThen(configProvider);
// Type: Cont<(), Never, List<User>>

result.run((), onThen: print);
```

---

## Else-Channel Injection

### elseInject

```dart
Cont<E, F2, A> elseInject<F2>(Cont<F, F2, A> cont)
```

Injects the error value of this continuation as the environment for another continuation.

The error-channel counterpart of `thenInject`. If this continuation terminates with an error of type `F`, that error is used as the environment for `cont`.

- **Type Parameters:**
  - `F2`: The error type of the target continuation

- **Parameters:**
  - `cont`: The continuation that will receive this continuation's error as its environment

**Returns:** A continuation that, on error:
1. Takes the error of type `F`
2. Uses it as the environment for `cont`
3. Produces `cont`'s result

**Example:**
```dart
// A continuation that might fail with a retry config
final operation = fetchData();

// A retry handler that uses the error as environment
final retryHandler = Cont.askThen<String, int>()
  .thenDo((errorMsg) => logAndRetry(errorMsg));

final result = operation.elseInject(retryHandler);
```

---

### injectedByElse

```dart
Cont<E0, F, A> injectedByElse<E0>(Cont<E0, E, A> cont)
```

Receives the environment for this continuation from another continuation's error.

The inverse of `elseInject`. The outer continuation `cont` terminates with an error of type `E`, which becomes the environment for this continuation.

Equivalent to `cont.elseInject(this)`.

- **Type Parameters:**
  - `E0`: The environment type of the outer continuation

- **Parameters:**
  - `cont`: The continuation whose error becomes this continuation's environment

**Example:**
```dart
final handler = Cont.askThen<ErrorInfo, int>()
  .thenDo((info) => recoverFromError(info));

final operation = Cont.error<(), ErrorInfo, int>(ErrorInfo('timeout'));

final result = handler.injectedByElse(operation);
```

---

## Usage Patterns

### Dependency Injection

```dart
// Define services that need dependencies
class UserService {
  Cont<Database, String, User> getUser(int id) {
    return Cont.askThen<Database, String>().thenDo((db) {
      return db.query('SELECT * FROM users WHERE id = ?', [id]);
    });
  }
}

// Build the dependency
final dbCont = Cont.of<(), Never, Database>(Database('localhost'));

// Inject it into the service operation
final service = UserService();
final result = dbCont.thenInject(service.getUser(123));

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
final dbOperation = Cont.askThen<DbConfig, String>()
  .thenDo((db) => queryUsers(db));

// Layer 3: Inject DB config from app config
final result = appConfigCont.thenDo((appConfig) {
  return dbOperation.withEnv(appConfig.database);
});
```
