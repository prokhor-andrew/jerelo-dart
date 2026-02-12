# Jerelo Documentation

Complete documentation for the Jerelo continuation library for Dart.

## Quick Navigation

### User Guide

A comprehensive guide to understanding and using Jerelo:

1. [Introduction & Core Concepts](user_guide/01-introduction.md) - Understanding computations and continuation-passing style
2. [Fundamentals: Construct & Run](user_guide/02-fundamentals.md) - Learn to create and execute computations
3. [Core Operations](user_guide/03-core-operations.md) - Master mapping, chaining, branching, and error handling
4. [Advanced Operations](user_guide/04-advanced-operations.md) - Parallel execution, racing, and complex workflows
5. [Environment Management](user_guide/05-environment.md) - Configuration and dependency injection patterns
6. [Extending Jerelo](user_guide/06-extending.md) - Create custom operators and computations
7. [Complete Examples](user_guide/07-examples.md) - Real-world patterns and use cases

### API Reference

Complete reference for all public APIs:

- **[API Overview](api/)** - Quick start and core concepts
- **[Types](api/types.md)** - ContError, ContRuntime, ContObserver
- **[Construction](api/construction.md)** - Creating continuations with constructors and decorators
- **[Execution](api/execution.md)** - Running continuations: ContCancelToken, run, ff
- **[Then Channel](api/then.md)** - Success path operations: mapping, chaining, tapping, zipping, forking, loops, conditionals
- **[Else Channel](api/else.md)** - Error path operations: recovery, fallback, error handling
- **[Combining](api/combining.md)** - Parallel execution: ContBothPolicy, ContEitherPolicy, both, all, either, any
- **[Environment](api/env.md)** - Environment management: local, scope, ask, injection

## Getting Started

**New to Jerelo?** Follow this learning path:

1. Start with [Introduction & Core Concepts](user_guide/01-introduction.md) to understand what Jerelo is and why continuation-passing style matters
2. Follow [Fundamentals: Construct & Run](user_guide/02-fundamentals.md) to learn how to create and execute computations
3. Master [Core Operations](user_guide/03-core-operations.md) for essential transformation and composition patterns
4. Reference the [API docs](api/) as needed for detailed method signatures and behaviors

**Already familiar with continuations?** Jump to:
- [Complete Examples](user_guide/07-examples.md) for real-world patterns
- [API Reference](api/) for quick lookup
- [Extending Jerelo](user_guide/06-extending.md) to build custom operators

## What is Jerelo?

**Jerelo** is a Dart library for building cold, lazy, reusable computations using continuation-passing style. Unlike Dart's `Future` which starts executing immediately upon creation, `Cont` computations are:

- **Cold** - Doesn't run until you explicitly call `run`
- **Pure** - No side effects during construction
- **Lazy** - Evaluation is deferred
- **Reusable** - Can be safely executed multiple times with different configurations
- **Composable** - Build complex flows from simple, testable pieces

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

---

[← Back to Main README](../README.md)
