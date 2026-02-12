# Jerelo API Documentation

Complete reference for all public types and APIs in the Jerelo continuation library.

---

## Table of Contents

### Core Concepts
- **[Types](api/types.md)** - Core types: `ContError`, `ContRuntime`, `ContObserver`
- **[Construction](api/construction.md)** - Creating continuations with constructors and decorators
- **[Execution](api/execution.md)** - Running continuations: `ContCancelToken`, `run`, `ff`, and extensions

### Operations
- **[Then Channel](api/then.md)** - Success path operations: mapping, chaining, tapping, zipping, forking, loops, and conditionals
- **[Else Channel](api/else.md)** - Error path operations: recovery, fallback, error handling
- **[Combining](api/combining.md)** - Parallel execution: `ContBothPolicy`, `ContEitherPolicy`, `both`, `all`, `either`, `any`
- **[Environment](api/env.md)** - Environment management: `local`, `scope`, `ask`, injection

---

## Quick Start

```dart
// Create a continuation
final cont = Cont.of<MyEnv, int>(42);

// Chain operations
final result = cont
  .thenMap((n) => n * 2)
  .thenDo((n) => fetchData(n))
  .recover((errors) => defaultValue);

// Execute
final token = result.run(
  myEnv,
  onThen: (value) => print('Success: $value'),
  onElse: (errors) => print('Failed: $errors'),
);
```

---

## What is Cont?

```dart
final class Cont<E, A>
```

A continuation monad representing a computation that will eventually produce a value of type `A` or terminate with errors.

**Type Parameters:**
- `E`: The environment type providing context for the continuation execution
- `A`: The value type that the continuation produces upon success

`Cont` provides a powerful abstraction for managing asynchronous operations, error handling, and composition of effectful computations. It follows the continuation-passing style where computations are represented as functions that take callbacks for success and failure.

---

## Documentation Structure

Each documentation file focuses on a specific aspect of the library:

- **Types** - Understand the foundational types and policies
- **Construction** - Learn how to create and decorate continuations
- **Execution** - Discover how to run continuations and use extensions
- **Then Channel** - Master success path operations and control flow
- **Else Channel** - Handle errors and implement recovery strategies
- **Combining** - Execute multiple continuations in parallel
- **Environment** - Manage contextual information and dependencies

All public APIs are documented with their behavior, parameters, and usage examples.
