# Jerelo User Guide

Welcome to the Jerelo documentation! This guide will help you learn how to build cold, lazy, reusable computations in Dart.

## What is Jerelo?

**Jerelo** is a Dart library for building cold, lazy, reusable computations. It provides operations for chaining, transforming, branching, merging, and error handling.

## Documentation Structure

Choose your learning path based on your needs:

### For Beginners

1. **[Introduction & Core Concepts](01-introduction.md)** - Start here to understand what Jerelo is and why it matters
   - What is Jerelo?
   - Understanding computation
   - Continuation-Passing Style (CPS)
   - Result channels and error handling

2. **[Fundamentals: Construct & Run](02-fundamentals.md)** - Learn to create and execute your first computations
   - Creating computations
   - Executing computations
   - Resource management
   - Key properties

### For Building Applications

3. **[Core Operations: Transform, Chain & Branch](03-core-operations.md)** - Master the essential operations
   - Transforming values
   - Chaining computations
   - Conditional logic and loops
   - Error handling

4. **[Advanced Operations: Merge & Execution Policies](04-advanced-operations.md)** - Handle concurrent operations
   - Running multiple computations
   - Racing computations
   - Execution policies
   - Parallel patterns

5. **[Environment Management](05-environment.md)** - Manage configuration and dependencies
   - Accessing environment
   - Scoping and transforming
   - Dependency injection
   - WithEnv variants

### For Advanced Users

6. **[Extending Jerelo](06-extending.md)** - Create custom abstractions
   - Custom computations
   - Custom operators
   - Using the `decor` operator
   - Cancellation support

7. **[Complete Examples & Patterns](07-examples.md)** - See it all come together
   - Full working examples
   - Common patterns
   - Best practices

### Reference

8. **[API Reference](api-reference.md)** - Complete API documentation
   - All operators organized by category
   - Quick lookup reference

## Quick Start

If you're in a hurry, here's a minimal example:

```dart
import 'package:jerelo/jerelo.dart';

// Create a computation
final computation = Cont.of(42)
  .thenMap((value) => value * 2)
  .thenDo((value) {
    print("Processing: $value");
    return Cont.of(value + 10);
  });

// Execute it
computation.run(
  (), // environment (not needed here)
  onThen: (result) => print("Result: $result"), // prints: Result: 94
  onElse: (errors) => print("Failed: $errors"),
);
```

## Key Concepts at a Glance

- **Cold**: Computations don't run until you call `run`
- **Lazy**: Evaluation is deferred
- **Reusable**: Execute the same computation multiple times
- **Composable**: Build complex workflows from simple pieces
- **Two channels**: Success channel (values) and termination channel (errors)

## Need Help?

- Check the [API Reference](api-reference.md) for quick lookups
- See [Complete Examples](07-examples.md) for real-world patterns
- Review [Introduction](01-introduction.md) if concepts are unclear

## What "Jerelo" Means

**Jerelo** is a Ukrainian word meaning "source" or "spring". Each `Cont` is a source of results. Like a spring that feeds a stream, a `Cont` produces a flow of data. Streams can branch, merge, filter, and transform what they carry, and Jerelo's API lets you model the same kinds of operations in your workflows.
