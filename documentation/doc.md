
# What is Jerelo?

**Jerelo** is a minimal, lawful Dart functional toolkit built around 
a CPS-based `Cont<A>` abstraction for composing synchronous/asynchronous 
workflows with structured termination and error reporting, 
plus practical operators for sequencing and concurrency.

# What is Continuation?

Usually when you need to encode a computation, you use functions.


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

Instead of returning a result, a callback is passed to the function. 
When the result is computed, the callback is invoked with a value.

# What problem does CPS solve?

The classic pure function can only be executed synchronously. 
By its encoding, it is forced to return a value immediately on the same call stack.
In CPS, the continuation is passed, which can be saved and executed at any time later.
This enables async programming.


# Why not Future?

Dart's `Future` is, in fact, CPS with syntactic sugar on top of it.
But the problem is it starts running as soon as it is created. 
This does not allow us to separate construction of a computation from 
execution.

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


# Solution

**Cont** is a type that represents an arbitrary computation. It has two result 
channels, and comes with a basic interface that allows you to do every fundamental operation:
- Construct
- Transform
- Chain
- Merge
- Race
- Recover
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

# Result channels

As mentioned before, `Cont` has two channels. One is for a successful result
and another one for termination.

Success is represented by the type parameter `T` in `Cont<T>`.

Termination is represented by `List<ContError>`.
The `List<ContError>` stands for the list of errors that caused the termination.
It may be empty or not.
This channel is used when a computation crashes. It can also be used
to manually terminate the computation.

```dart

final program = getUserAge(userId).map((age) {
  throw "Armageddon!"; // <- throws here
});

// or

final program = getUserAge(userId).flatMap((age) {
  return Cont.terminate([ContError("Armageddon!", StackTrace.curret)]);
});

program.run((errors) {
  // will automatically catch thrown error here
}, (value) {
  // success channel. not called in this case
  print("value=$value");
});
```

The type of a thrown error is `ContError`. It is a holder for the original error and 
stack trace.

```dart
final class ContError {
  final Object error;
  final StackTrace stackTrace;

  const ContError(this.error, this.stackTrace);
}
```

# Constructing

`Cont` has one base constructor:
- `Cont.fromRun`

One utility constructors:
- `Cont.fromDeferred`

One constructor with lifecycle:
- `Cont.withRef`

And lawful identities to some operators:
- `Cont.of`
- `Cont.terminate`

To construct a `Cont` object - utilize any of the above.

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
- It is idempotent. Calling `onValue` or `onTerminate` more than once, will do nothing.
- It is mandatory to call `onValue` or `onTerminate` once the computation is over. 
Otherwise, errors will be lost, and behavior becomes undefined. 

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
Cont.terminate([
  ContError("payload", StackTrace.current),
]); // 
```

# Running 

Constructing a computation is only a first step. To actually trigger its execution, 
one has to call `run` on it, passing `onTerminate` callback, as well as `onValue` one.



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
pure, and lazy by design. It can be safely executed multiple times,
passed around in functions, and stored as values in constants.


When `run` is called, the flow goes "up" the chain, executes the edge
computation (the `Cont` object we get from `getValueFromDatabase`)
and then navigates back down to `flatMap(incrementValue)`, then to `flatMap(isEven)`, 
to `flatMap(toString)`, and finally to `run` itself.

If any computation emits a termination event, the whole chain after that 
is skipped and first callback passed into `run` is invoked.

# Transforming

To transform value inside `Cont`, use `map`:

```dart
Cont.of(0).map((zero) { 
  return zero + 1;
}).run((_) {}, print); // prints 1
```

# Chaining

Chaining is constructing a computation from the result 
of the previous one. To achieve this one can use `flatMap`:

```dart
Cont.of(0).flatMap((zero) {
  return Cont.of(zero + 1);
}).run((_) {}, print); // prints 1
```

There is also a variant for `List` of continuations. It is called
`Cont.sequence`. It runs every computation one by one, until it reaches 
the end, and emits the last value.

```dart
Cont.sequence([
    Cont.of(5),
    Cont.of(4),
    Cont.of(3),
    Cont.of(2),
    Cont.of(1),
]).run((_) { }, print); // prints 1
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
).run((_) {}, print); // prints 1
```

When you have a list of computations, and you want to
wait for all their values, `Cont.all` is your tool.

```dart
final List<Cont<int>> contList = [
  Cont.of(1),
  Cont.of(2),
  Cont.of(3),
]; 

Cont.all(contList).run((_) {}, print); // prints [1, 2, 3]
```

# Racing

You can also run independent computations, and pick the first successful value.
This is called `raceForWinner`:

```dart
Cont.raceForWinner(
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 4))).mapTo("first"),
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 1))).mapTo("second"),
).run((_) {}, print); // prints "second"
```

Note on `raceForWinner`, it will emit the value as soon as it is available,
without waiting for other computations to complete.


In case you want to get the last non-terminating value, use `raceForLoser`:

```dart
Cont.raceForLoser(
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 4))).mapTo("first"),
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 1))).mapTo("second"),
).run((_) {}, print); // prints "first"
```

In the loser case, all computations must be finished, in order to properly determine
last non-terminating value.

There are also two variants for `List<Cont<A>>` - `raceForWinnerAll`:


```dart
Cont.raceForWinnerAll([
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 4))).mapTo("first"),
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 1))).mapTo("second"),
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 5))).mapTo("third"),
]).run((_) {}, print); // prints "second"
```

And `raceForLoserAll`:

```dart
Cont.raceForLoserAll([
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 4))).mapTo("first"),
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 1))).mapTo("second"),
  Cont.fromFutureComp(() => Future.delayed(Duration(seconds: 5))).mapTo("third"),
]).run((_) {}, print); // prints "third"
```

# Recovering

Dart is fragile. Anything can throw. Luckily, Jerelo does most of the work for you.
Any failed computation will be propagated downstream via terminate channel. 

But sometimes we may want to recover from an error, and continue.

To do this there is `orElseWith` operator. It catches any termination event.

```dart
Cont.terminate([
  ContError("Error object", StackTrace.current)
])
.orElseWith((errors) => Cont.of(2)) 
.run((_) {}, print); // prints 2
```

There is a variant for a `List` of continuations: `Cont.orElseAll`. It
runs computations one by one, until it finds one that succeeds.

```dart
Cont.orElseAll([ 
  Cont.terminate(),
  Cont.of(0),
  Cont.of(5),
])
.run((_) {}, print); // prints 0
```

# Final Example

There are more operators in [api.md](api.md), and 
I highly recommend getting to know them. They are not different from the ones
described in this document, but rather minor sugar extensions of them.

Lastly, I want to showcase an example of everything in one place:


```dart
final cont = Cont.fromRun<int>((observer) { // constructing
  final n = Random().nextInt(10); // 0..9 randomized
  observer.onValue(n);
})
.map((int value) => value.isEven) // transforming
.flatMap((isEven) { // chaining
  if (isEven) {
    return Cont.both( // merging
      Cont.of(10),
      Cont.of(20),
      (ten, twenty) => ten + twenty,
    );
  } else {
    final cache = Cont.of(111); // 5 milliseconds
    final network = Cont.of(222); // 80 milliseconds

    return Cont.raceForWinner(cache, network); // racing
  }
})
.orElseWith((errors) => Cont.of(-1)); // recovering

// whenever you are ready    
cont.run(print, print); // running
```

# What "Jerelo" means

**Jerelo** is a Ukrainian word meaning “source” or “spring”.

Each `Cont` is a source of results. 
Like a spring that feeds a stream, a `Cont` produces a 
flow of data. Streams can branch, merge, filter, and 
transform what they carry, and Jerelo’s API lets you model 
the same kinds of operations in your workflows.