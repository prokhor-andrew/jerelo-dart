
# What is Jerelo?

**Jerelo** is a minimal, lawful Dart functional toolkit built around 
a CPS-based `Cont<A>` abstraction for composing synchronous/asynchronous 
workflows with structured termination and error reporting, 
plus practical operators for sequencing and concurrency.

# What is Continuation?

Usually when one needs to encode a computation he uses functions.


```dart
int increment(int value) {
  return value + 1;
}

final result = increment(5); // 6
```

Another way to achieve the same result is by using **Continuation Passing Style** (CPS).


```dart
// `callback` is a continuation
void increment(int value, void Function(int result) callback) { 
  callback(value + 1);
}

increment(5, (result) { 
  // result == 6
});
```

Instead of returning result, a callback is passed to the function. 
When the result is computed, the callback is invoked with a result value.

# What problem does CPS solve?

The classic pure function can only be executed synchronously. 
By its encoding, it is forced to return value immediately on the same call-stack.
In CPS, the continuation is passed, which can be saved and executed any time later.
This enables async programming.


# Why not Future?

Dart's `Future` - is, in fact, CPS with language sugar on top of it.
But its problem is it starts running as soon as it is created. 
This does not allow us to separate construction of computation from 
its execution.

```dart

final getUserComputation = Future(() {
  // getting user here
});

// getUserComputation is already running.
```

# The problem of CPS

While normal functions and `Future`s compose nicely, CPS doesn't.

```dart

// normal composition
final result1 = function1(value);
final result2 = function2(result1);
final result3 = function2(result2);

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


# Solution

**Cont** - is a type that represents an arbitrary computation. 
It comes with basic interface that allows to do every fundamental operation:
- Construct
- Transform
- Chain
- Merge
- Choose
- Recover
- Schedule
- Run


Example:

```dart
// Cont composition

final Cont<Result1Type> result1Cont = function1(value);
final Cont<Result2Type> result2Cont = result1Cont.flatMap((result1) {
  return function2(result1);
});

final Cont<ProgramType> program = result2Cont.flatMap((result2) {
  // the rest of the program
});
```

But that is tedious and not the right way to use it. Here is the right one:

```dart
// Cont composition

final Cont<ProgramType> program = function1(value)
  .flatMap((result1) {
    return function2(result1);
  })
  .flatMap((result2) {
    // the rest of the program
  });
```

Or even better:

```dart
// Cont composition

final program = function1(value)
  .flatMap(function2)
  .flatMap((result2) {
    // the rest of the program
  });
```

# Data channels

`Cont` has two data channels. One is for successful result
and another one for termination.

Success is the one expressed by type parameter `T` in `Cont<T>`.

Termination - by `List<ContError>`.
The `List<ContError>` stands for the list of errors that caused the termination.
It can be empty or not.
This channel is used when a computation crashes. It can also be used
to manually terminate the computation.

```dart

final program = getUserAge(userId).map((age) {
  return age / 0; // <- throws here
});

program.run((errors) {
  // will automatically catch thrown error here
}, (value) {
  // success channel. not called in this case
  print("value=$value");
});
```

The type of thrown error is `ContError`. It is a holder for original error and 
stack trace.

```dart
final class ContError {
  final Object error;
  final StackTrace stackTrace;

  const ContError(this.error, this.stackTrace);
}
```

# Construction

`Cont` has one base constructor:
- `Cont.fromRun`

Two utility constructors:
- `Cont.fromDeferred`
- `Cont.fromFutureComp`

One stateful constructor:
- `Cont.withRef`

And lawful identities to some operators:
- `Cont.of`
- `Cont.terminate`
- `Cont.empty`
- `Cont.raise`

To construct a `Cont` object - utilize any of the above.


For example, one can wrap an existing `Future` like this:

```dart
Future<User> getUserById(String userId) {
  // implementation omitted
}

Cont<User> getUser(String userId) {
  return Cont.fromFutureComp(() {
    final userFuture = getUserById(userId);
    return userFuture;
  });
}
```

Or if you have callbacks, use `Cont.fromRun`:

```dart
Cont<User> getUser(String userId) {
  return Cont.fromRun((observer) {
    try {
      final userFuture = getUserById(userId, (user) {
        observer.onValue(user);
      });
    } catch (error, st) {
      observer.onTerminate([ContError(error, st)]);
    }
  });
}
```

There are a couple of things to note about `observer` here:
- It is idempotent. Calling `onValue` or `onTerminate` more then once will do nothing.
- It is mandatory to call `onValue` or `onTerminate` once the computation is over. 
Otherwise, any potential errors will be lost, in addition to the other unexpected behavior involved. 

Sometimes one would prefer to defer a construction of a `Cont`.
In the example below, getting `userId` is expensive, so we want to 
delay that until the `Cont<User>` is run.

```dart 
Cont<User> getUserByIdThunk(UserId Function() expensiveGetUserId) {
  return Cont.fromDeferred(() {
    final userId = expensiveGetUserId();
    final userCont = getUser(userId);
    return userCont;
  });
}
```

Primitive constructors are also available:

```dart
Cont<User> getUser(String userId) {
  final User user = getUserSync(userId); // evaluated eagerly
  return Cont.of(user); 
}
```

To represent terminated computation with or without errors use:

```dart

Cont.empty(); // no errors

Cont.raise(ContError(error, stackTrace), []); // at least one error

Cont.terminate([]); // combines both above
```

If you need to resource lifecycle management, `Cont.withRef` is your friend.

```dart
 // TODO: 
```


# Running 

The resulting object of type `Cont<T>`, where `T`
is the result of the last computation, won't just start after 
its construction.

In order to actually run it, one has to call `run` on it, 
passing `onTerminate` callback, as well as `onValue` one.

Example:

```dart
// constructing the program
final Cont<String> program = getValueFromDatabase()
  .flatMap(incrementValue)
  .flatMap(isEven)
  .flatMap(toString);

// running the program
program.run(
  (errors) {
    // handle errors
    print("TERMINATED with errors=$errors");
  },
  (value) {
    // handle computed result  
    print("SUCCEEDED with value=$value");
  },
);
```

The example above showcases how construction of computation is
separated from its execution. 

Any object of type `Cont` is cold,
pure and lazy by design. It can be safely executed multiple times,
passed around in functions, and stored as values in constants.


When `run` is called, the flow goes "up" the chain, executes the edge
computation (the `Cont` object we get from `getValueFromDatabase`)
and then navigates back down to `flatMap(incrementValue)`, then to `flatMap(isEven)`, 
to `flatMap(toString)`, and finally to `run` itself.

If any computation emits termination event, the whole chain after that 
is skipped and first callback passed into `run` is invoked.

# Transformation

To transform value inside `Cont`, use `map`:

```dart
Cont.of(0).map((zero) { 
  return zero + 1;
}).run(print, print); // prints 1
```

# Chaining

Chaining - is constructing and running a computation from the result 
of the previous one. To achieve this one can use `flatMap`:

```dart
Cont.of(0).flatMap((zero) {
  return Cont.of(zero + 1);
}).run(print, print); // prints 1
```

Sometimes you want to construct and run a computation from a previous value,
but ignore the result and pass the value you received in the first place.
For that, use `flatTap`:

```dart
Cont.of(0).flatTap((zero) {
  return Cont.of(zero + 100);
}).run(print, print); // ignores + 100 and prints 0
```

# Merging

When you have two independent computations, and you need to get
the result from both, use `Cont.both`:

```dart
final zeroCont = Cont.of(0);
final oneCont = Cont.of(1);

Cont.both(
  zeroCont, 
  oneCont, 
  (zero, one) => zero + one,
).run(print, print); // prints 1
```

In case of a `List<Cont<T>>>` - use `Cont.all` to get `Cont<List<T>>`:

```dart
final List<Cont<int>> contList = [
  Cont.of(1),
  Cont.of(2),
  Cont.of(3),
]; 

Cont.all(contList).run(print, print); // prints [1, 2, 3]
```

Basically, when you have a list of computations, and you want to
wait for all their values, `Cont.all` is your tool. 

# Choosing

// TODO: 

# Recovering

// TODO:

# Scheduling

// TODO:

# Example

// TODO: 


# Why bother?

Software tends to degrade when core logic becomes tightly coupled to implementation details. One release uses one HTTP client; the next swaps it out. A “service” that started as direct calls later needs caching, retries, and logging. UI, databases, and APIs evolve, and without a composable boundary, business logic ends up entangled with those changes.

Jerelo is a small, pure-Dart library for expressing business workflows as composable building blocks. When flows are composable, dependencies stay replaceable: you can swap a function, a service, or an entire boundary (HTTP/UI/DB) without rewriting the pipeline.

Jerelo also makes two practical constraints explicit:

- **Dart can throw anywhere**. Jerelo models failure as part of the contract, so errors do not surface as surprise crashes or scattered try/catch.

- **Async needs control**. If you cannot control when work runs, you cannot test it reliably. Jerelo brings scheduling into the model so production can be async while tests remain deterministic.

Jerelo is not a UI/state wiring framework. It does not prescribe Flutter patterns or a specific ecosystem. It is a compact core for building modular, scalable workflows, and it can be used alongside tools like Provider or Riverpod when you want them.


# What "Jerelo" means

**Jerelo** is a Ukrainian word meaning “source” or “spring”.

Each `Cont` is a source of results. 
Like a spring that feeds a stream, a `Cont` produces a 
flow of data. Streams can branch, merge, filter, and 
transform what they carry, and Jerelo’s API lets you model 
the same kinds of operations in your workflows.