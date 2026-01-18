


# What is Jerelo?

Jerelo is a library that provides Cont type.

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
This does not allow us to separate construction of computation from its execution.

```dart

final getUserComputation = Future(() {
  // getting user here
});

// getUserComputation is already running.
```

# The problem of CPS

The problem of CPS is composition. 
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


Example:

```dart
// Cont composition

final program = function1(value).flatMap((result1) {
  return function2(result1);
}).flatMap((result2) {
  // the rest of the program
});
```

Or even better

```dart
// Cont composition

final program = function1(value)
    .flatMap(function2)
    .flatMap((result2) {
      // the rest of the program
    });
```

# Running computations

Both `program` objects are of type ```Cont<T>``` where ```T``` 
is the result of the last computation.

The computation won't start after its construction. In order 
to actually run it, one has to call ``run`` on it, passing
``ContReporter`` and ``ContObserver<T>``.

Example:
```dart 

final Cont<String> program = getValueFromDatabase()
    .flatMap(incrementValue)
    .flatMap(isEven)
    .flatMap(toString);


// running the program
program.run(
  ContReporter.ignore(), // will be explained later
  ContObserver(
    (errors) {
      // handle errors
      print("FAILED with errors=$errors");
    },
    (value) {
      // handle computed result  
      print("SUCCEEDED with value=$value");
    },
  ),
);
```

The example above showcases how construction of computation is 
separated from its execution. Any object of type ``Cont`` is cold,
pure and lazy by definition. It can be safely executed multiple times.

# Data channels

```Cont``` has two data channels. One is for successful result 
and another one for terminated computations.

Success is the one expressed by type parameter ``T`` in ``Cont<T>``.

Termination - by ``List<Object>``. 
The ``List<Object>`` stands for the list of errors that caused the termination.
It can be empty or not.
This channel is used when computation crashes. It can also be used
to manually terminate the computation.


# Constructors

``Cont`` has two fundamental constructors:
- Cont.fromRun
- Cont.fromDeferred

And lawful identities to some operators:
- Cont.of
- Cont.terminate
- Cont.empty
- Cont.raise

# Operators

``Cont`` comes with a set of operators that allow to compose computations.

They are:
- map
- flatMap
- catchTerminate
- catchError
- catchEmpty
- filter
- Cont.both
- Cont.all
- Cont.race
- Cont.raceAll
- Cont.either
- Cont.any