[Home](../../README.md) > User Guide

# Introduction & Core Concepts

### Understanding Computation

A **computation** is a constructible description of how a value can be produced. Its key feature is the separation of construction from execution.

```dart
// construction of the computation
Future<int> getValue() {
  return Future.delayed(Duration(seconds: 1), () {
    return 42;
  });
}

// execution of the computation
getValue();
```

It's worth noting that `Future<int>` is **not** a computation. `getValue` is.

Whenever we construct a future object, its execution starts immediately. We cannot run it later.

### Why Composition Matters

The reason we care about computations is their ability to compose.

**Composition** is a technique of combining two or more computations together to get a new one.

Composability guarantees many important features such as:
- Reusability
- Testability
- Substitution
- Observability
- Refactorability (if that's a word)

and many more.

### What is Continuation?

Usually when you need to encode a computation, you use functions that return a value.

```dart
int increment(int value) {
  return value + 1;
}

final result = increment(5); // 6
```

Another way to achieve the same result is to use **Continuation-Passing Style** (CPS).

```dart
// `callback` is a continuation
void increment(int value, void Function(int result) callback) {
  callback(value + 1);
}

increment(5, (result) {
  // result == 6
});
```

Instead of returning a result, a callback is passed to the function. When the result is computed, the callback is invoked with a value.

### What Problem Does CPS Solve?

The classic pure function can only be executed synchronously. By its encoding, it is forced to return a value immediately on the same call stack. In CPS, the continuation is passed, which can be saved and executed at any time later. This enables asynchronous programming.

### Why Not Future?

Dart's `Future` is, in fact, CPS with syntactic sugar on top of it. But as it was mentioned above, `Future` starts running as soon as it is created, thus it is not composable.

```dart
final getUserComputation = Future(() {
  // getting user here
});

// getUserComputation is already running.
```

### The Problem of CPS

While normal functions and `Future`s compose nicely, CPS doesn't.

```dart
// normal composition
final result1 = function1(value);
final result2 = function2(result1);
final result3 = function3(result2);

// async composition
// in async function

final result1 = await function1(value);
final result2 = await function2(result1);
final result3 = await function3(result2);

// CPS composition
function1(value, (result1) {
  function2(result1, (result2) {
    function3(result2, (result3) {
      // the rest of the program
    });
  });
});
```

As you can see, the more functions we want to compose, the uglier it becomes.

### The Solution: Jerelo's Cont

**Cont** is a type that represents an arbitrary computation. It has two result channels, and comes with a basic interface that allows you to do every fundamental operation:
- Construct
- Run
- Transform
- Chain
- Branch
- Merge

Example of `Cont`'s composition:

```dart
// Cont composition

final program = function1(value)
  .thenDo(function2)
  .thenDo((result2) {
    // the rest of the program
  });
```

## Getting Started with Cont

`Cont` has two result channels:
- **Success channel**: Represented by the type parameter `T` in `Cont<E, T>`
- **Termination channel**: Represented by `List<ContError>` for errors that caused termination

### Result Channels

The termination channel is used when a computation crashes or when you manually terminate it.

```dart
final program = getUserAge(userId).thenMap((age) {
  throw "Armageddon!"; // <- throws here
});

// or

final program = getUserAge(userId).thenDo((age) {
  return Cont.stop([ContError.capture("Armageddon!")]);
});

// ignore `()` for now
final token = program.run(
  (),
  onElse: (errors) {
    // will automatically catch thrown error here
  },
  onThen: (value) {
    // success channel. not called in this case
    print("value=$value");
  },
);
```

### ContError Type

The type of a thrown error is `ContError`. It is a holder for the original error and stack trace. Instances are created via static factory methods:

```dart
final class ContError {
  final Object error;
  final StackTrace stackTrace;

  // From a catch block — preserves the caught stack trace
  ContError.withStackTrace(error, stackTrace);

  // When no stack trace is needed
  ContError.withNoStackTrace(error);

  // Captures the stack trace at the call site automatically
  ContError.capture(error);
}
```

---

## Next Steps

Now that you understand the core concepts, continue to:
- **[Fundamentals: Construct & Run](02-fundamentals.md)** - Learn to create and execute computations
- **[Core Operations](03-core-operations.md)** - Master the essential operations
