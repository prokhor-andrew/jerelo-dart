# Jerelo Documentation

Welcome to the comprehensive documentation for **Jerelo** - a Dart library for building cold, lazy, reusable computations.

## Quick Links

- **[User Guide Index](user_guide/index.md)** - Start here for an overview
- **[API Reference](user_guide/api-reference.md)** - Complete API documentation

## Documentation Structure

The documentation is organized into focused guides that you can read sequentially or jump between based on your needs.

### Getting Started

#### [Introduction & Core Concepts](user_guide/01-introduction.md)
Learn what Jerelo is and why it matters. This guide covers:
- What is Jerelo and why use it?
- Understanding computation vs execution
- Continuation-Passing Style (CPS)
- The problem Jerelo solves
- Result channels and ContError type

**Start here if:** You're new to Jerelo or want to understand the concepts behind it.

#### [Fundamentals: Construct & Run](user_guide/02-fundamentals.md)
Master the basics of creating and executing computations. This guide covers:
- Constructing computations (fromRun, of, stop, fromDeferred)
- Resource management with bracket
- Executing computations with run and ff
- Key properties (Cold, Pure, Lazy, Reusable)
- Understanding execution flow
- The environment parameter

**Start here if:** You want to write your first Jerelo code.

### Building Applications

#### [Core Operations: Transform, Chain & Branch](user_guide/03-core-operations.md)
Master the essential operations for building workflows. This guide covers:
- Transform: Mapping and hoisting values
- Chain: Success and error chaining (thenDo, elseDo)
- Branch: Conditional logic (thenIf, elseIf, abort)
- Looping: thenWhile, thenUntil, forever
- Error retry: elseWhile, elseUntil
- Working with Never-producing continuations

**Start here if:** You're ready to build complex computation chains.

#### [Advanced Operations: Merge & Execution Policies](user_guide/04-advanced-operations.md)
Handle concurrent operations and parallel execution. This guide covers:
- Execution policies explained (ContBothPolicy, ContEitherPolicy)
- Running multiple computations (both, all)
- Racing computations (either, any)
- Policy selection guide
- Common parallel patterns

**Start here if:** You need to run multiple computations concurrently.

#### [Environment Management](user_guide/05-environment.md)
Manage configuration, dependencies, and context. This guide covers:
- What is environment and why use it?
- Accessing environment (ask)
- Scoping and transforming (scope, local)
- WithEnv variants explained
- Dependency injection patterns (injectInto, injectedBy)
- Common environment patterns

**Start here if:** You need to thread configuration or dependencies through your code.

### Advanced Topics

#### [Extending Jerelo](user_guide/06-extending.md)
Create custom computations and operators. This guide covers:
- Creating custom computations with fromRun
- Creating custom operators (composition, decor)
- Cancellation support with runtime
- Best practices for custom extensions
- Complete custom operator examples

**Start here if:** You want to build custom abstractions on top of Jerelo.

#### [Complete Examples & Patterns](user_guide/07-examples.md)
Real-world examples and common patterns. This guide covers:
- Complete user management system example
- API client with retry and timeout
- Cache-then-network strategy
- Validation pipeline
- Parallel tasks with progress
- Circuit breaker pattern
- Request deduplication
- Rate limiting
- Best practices

**Start here if:** You want to see complete working examples and learn patterns.

### Reference

#### [API Reference](user_guide/api-reference.md)
Complete API documentation organized by category:
- All constructors and factory methods
- Transform, chain, tap, zip, fork operators
- Conditional and loop operators
- Error handling operators
- Merge and race operators
- Environment operators
- Execution methods
- Supporting types (ContError, ContCancelToken, ContObserver, ContRuntime)
- Variant patterns explained
- Quick reference by use case

**Start here if:** You need to look up a specific operator or method.

## Learning Paths

### Path 1: Quick Start (15 minutes)
1. [Introduction](user_guide/01-introduction.md) - Skim the concepts
2. [Fundamentals](user_guide/02-fundamentals.md) - Read construction and execution
3. [Examples](user_guide/07-examples.md) - Look at one complete example
4. Start coding!

### Path 2: Comprehensive (2-3 hours)
1. [Introduction](user_guide/01-introduction.md) - Understand the why
2. [Fundamentals](user_guide/02-fundamentals.md) - Learn construct & run
3. [Core Operations](user_guide/03-core-operations.md) - Master the essentials
4. [Advanced Operations](user_guide/04-advanced-operations.md) - Handle concurrency
5. [Environment](user_guide/05-environment.md) - Manage dependencies
6. [Examples](user_guide/07-examples.md) - See real patterns
7. Keep [API Reference](user_guide/api-reference.md) handy

### Path 3: Expert (Full depth)
Complete the comprehensive path, then:
1. [Extending Jerelo](user_guide/06-extending.md) - Build custom operators
2. Study all patterns in [Examples](user_guide/07-examples.md)
3. Review [API Reference](user_guide/api-reference.md) thoroughly

## What is Jerelo?

**Jerelo** is a Dart library for building **cold, lazy, reusable computations**. It provides a rich set of operations for:
- **Chaining** - Compose operations sequentially
- **Transforming** - Map and modify values
- **Branching** - Conditional logic and loops
- **Merging** - Combine and race computations
- **Error handling** - Recover and retry

### Key Features

- **Cold & Lazy**: Computations don't run until you explicitly call `run`
- **Reusable**: Execute the same computation multiple times
- **Composable**: Build complex workflows from simple pieces
- **Two-channel model**: Separate success and error channels
- **Type-safe**: Full type safety with Dart's type system
- **Environment support**: Thread configuration and dependencies automatically
- **Cancellation**: Cooperative cancellation for long-running operations

### Why "Jerelo"?

**Jerelo** (Джерело) is a Ukrainian word meaning "source" or "spring". Each `Cont` is a source of results—like a spring that feeds a stream. Streams can branch, merge, filter, and transform, and Jerelo's API lets you model the same operations in your computational workflows.

## Quick Example

```dart
import 'package:jerelo/jerelo.dart';

// Define a simple computation
final computation = Cont.of(42)
  .thenMap((value) => value * 2)
  .thenDo((value) {
    print("Processing: $value");
    return Cont.of(value + 10);
  })
  .elseDo((errors) {
    print("Error occurred, using fallback");
    return Cont.of(0);
  });

// Execute it
computation.run(
  (), // environment (not needed in this example)
  onThen: (result) => print("Result: $result"), // prints: Result: 94
  onElse: (errors) => print("Failed: $errors"),
);
```

## Contributing

Found an issue or have a suggestion? Please open an issue or pull request on the [GitHub repository](https://github.com/your-repo/jerelo).

## License

[Your license information here]

---

**Ready to get started?** Head to the [User Guide Index](user_guide/index.md) or jump straight to [Introduction & Core Concepts](user_guide/01-introduction.md).
