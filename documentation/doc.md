
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

Another way to achieve the same result is using **Continuation Passing Style** (CPS).


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

Dart's Future - is, in fact, CPS with language sugar on top of it.
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

While normal functions and Futures compose nicely, CPS doesn't.

```dart

// normal composition
final result1 = function1(value);
final result2 = function2(result1);

// async composition
// in async function

final result1 = await function1(value);
final result2 = await function2(result1);

// CPS composition
function1(value, (result1) {
  function2(result1, (result2) {
    // the rest of the program
  });
});
```

As you can see, the more functions we want to compose, the uglier it becomes.


# Solution


**Cont** - is a computation that can be constructed and run later.
It comes with basic interface that allows to do every fundamental operation:
- Construct
- Sequence
- Merge
- Branch
- Schedule


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
  print("value=$value");
});
```

The type of thrown error is `ContError`. It is a holder for original error and 
stack trace.

For reference:
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
Cont<User> getUser(String userId) {
  return Cont.fromRun((observer) {
    final userFuture = getUserById(userId); // <- returns Future<User> here
    userFuture.then((user) {
      observer.onValue(user);
    }).catchError((error, st) {
      observer.onTerminate([ContError(error, st)]);
    });
  });
}
```

But it is much better to use existing `Cont.fromFutureComp` to achieve the same result:

```dart
Cont<User> getUser(String userId) {
  return Cont.fromFutureComp(() {
    final userFuture = getUserById(userId);
    return userFuture;
  });
}
```

There are a couple of things to note about `Cont.fromRun`:
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

# Operators

`Cont` comes with a set of operators that allow to compose computations:

- `map`
- `flatMap`
- `flatTap`
- `catchTerminate`
- `catchError`
- `catchEmpty`
- `filter`
- `Cont.both`
- `Cont.all`
- `Cont.race`
- `Cont.raceAll`
- `Cont.either`
- `Cont.any`

and to control the execution:
- `subscribeOn`
- `observeOn`

The behavior of each individual operator is described in [api.md](api.md).

The core idea - to compose computations, transform value, and control their execution.

Example:

```dart
final getUserStreetCont = getUser(userId)
  .flatMap(getUserAddress)
  .filter((address) => address.country == Country.USA) // emits Cont.empty() when "false"
  .map((address) => address.street)
  .catchEmpty(() => Cont.of(Failure("No address found"))); // catches Cont.empty() from "filter"
  .catchError((error, _) => Cont.of(Failure("Something went wrong")))
  .subscribeOn(ContScheduler.delayed());

final getPaymentInfoCont = getPaymentInfo(userId)
  .catchTerminate((errors) => Cont.of(Failure("No Payment Info Found")))
  .subscribeOn(ContScheduler.microtask());
  
final program = Cont.both(
  getUserStreetCont,
  getPaymentInfoCont,
  (userStreet, paymentInfo) => Success((userStreet, paymentInfo)),
  isSequential: false, // execute concurrently
);
  
// later run

program.run(print, print);
```


If you are familiar with Rx, this is same idea. 
At first, construct a computation, describing each step that has to be 
executed after `run` is called. 

When `run` is called, one goes "up" the chain, executes the edge
computations (the `Cont` objects we get from `getUser` and `getPaymentInfo`) 
and then navigates back down.

The more detailed step by step guide can be found in [api.md](api.md).

# Running computations

The resulting `program` object is of type `Cont<T>` where `T` 
is the result of the last computation.

The computation won't start after its construction. In order 
to actually run it, one has to call `run` on it, passing `onTerminate`
callback as well as `onValue` one.

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
    print("FAILED with errors=$errors");
  },
  (value) {
    // handle computed result  
    print("SUCCEEDED with value=$value");
  },
);
```

The example above showcases how construction of computation is 
separated from its execution. Any object of type `Cont` is cold,
pure and lazy by design. It can be safely executed multiple times,
passed around in functions, and stored as values in constants.


# Why bother?

Because real apps rot when the code stops being swappable. Today it’s one HTTP client, tomorrow it’s another. Today your “service” is direct calls, tomorrow it’s cached + retried + logged. UI changes, DB changes, APIs change, and suddenly your business logic is glued to details.

Jerelo is my answer to that: a small, pure-Dart way to build business flows as LEGO blocks. When your flow is composable, everything becomes replaceable: a function, a service, or an entire 
boundary (HTTP/UI/DB) can be swapped without rewriting the pipeline.

It also makes two annoying realities explicit:

- Dart can throw anywhere. Jerelo treats failure as part of the contract, so errors don’t leak as random crashes or scattered try/catch.

- Async needs control. If you can’t control when things run, you can’t test them. Jerelo brings scheduling into the model so production can be async, and tests can be deterministic.

It’s not another state/UI wiring tool. No Flutter opinions. No provider/riverpod vibe. Just a compact core for modular, scalable, swappable execution of real workflows.

You can use those tools in addition to Jerelo though.