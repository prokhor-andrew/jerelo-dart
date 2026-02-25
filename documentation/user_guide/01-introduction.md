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

**Cont** is a type that represents an arbitrary computation. It has three result channels, and comes with a basic interface that allows you to do every fundamental operation:
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

`Cont<E, F, A>` has three type parameters and three result channels:

- **`E`** — Environment type: configuration, dependencies, or context threaded through the chain
- **`F`** — Error type: typed business-logic errors (e.g., `String`, a custom `AppError` enum, etc.)
- **`A`** — Value type: the success result

### Result Channels

Every `Cont` computation terminates on exactly one of three channels:

1. **Then channel** (success) — carries a value of type `A`
2. **Else channel** (business error) — carries a typed error of type `F`
3. **Crash channel** (unexpected exception) — carries a `ContCrash` value

```dart
final program = getUserAge(userId).thenMap((age) {
  throw "Armageddon!"; // <- throws here → crash channel
});

// or

final program = getUserAge(userId).thenDo((age) {
  return Cont.error("Too young"); // → else channel
});

// ignore `()` for now
final token = program.run(
  (),
  onCrash: (crash) {
    // crash channel: unexpected exceptions
    print("Crash: ${crash}");
  },
  onElse: (error) {
    // else channel: typed business-logic errors
    print("Error: $error");
  },
  onThen: (value) {
    // then channel: success
    print("value=$value");
  },
);
```

### ContCrash Type

When an exception is thrown inside a computation, it is automatically caught and wrapped in a `ContCrash`. The crash type hierarchy is:

```dart
sealed class ContCrash {
  // ...
}

// A single caught exception
final class NormalCrash extends ContCrash {
  final Object error;
  final StackTrace stackTrace;
}

// Two crashes combined from parallel or sequential operations
final class MergedCrash extends ContCrash {
  final ContCrash left;
  final ContCrash right;
}

// Multiple crashes collected from a list of operations
final class CollectedCrash extends ContCrash {
  final Map<int, ContCrash> crashes;
}
```

Unlike the typed error on the else channel (type `F`), crashes are untyped and represent unexpected failures — the equivalent of unhandled exceptions in traditional code.

---

## Next Steps

Now that you understand the core concepts, continue to:
- **[Fundamentals: Construct & Run](02-fundamentals.md)** - Learn to create and execute computations
- **[Core Operations](03-core-operations.md)** - Master the essential operations
