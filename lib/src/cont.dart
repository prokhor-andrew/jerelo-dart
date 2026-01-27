import 'package:jerelo/jerelo.dart';

/// A continuation monad representing a computation that will eventually
/// produce a value of type [A] or terminate with errors.
///
/// [Cont] provides a powerful abstraction for managing asynchronous operations,
/// error handling, and composition of effectful computations. It follows the
/// continuation-passing style where computations are represented as functions
/// that take callbacks for success and failure.
final class Cont<A> {
  final void Function(ContObserver<A> observer) _run;

  /// Executes the continuation with the provided observer.
  ///
  /// - [observer]: The observer containing callbacks for value and termination.
  void runWith(ContObserver<A> observer) {
    _run(observer);
  }

  /// Executes the continuation with separate callbacks for termination and value.
  ///
  /// Initiates execution of the continuation with separate handlers for success
  /// and failure cases.
  ///
  /// - [onTerminate]: Callback invoked when the continuation terminates with errors.
  /// - [onValue]: Callback invoked when the continuation produces a successful value.
  void run(void Function(List<ContError> errors) onTerminate, void Function(A value) onValue) {
    runWith(ContObserver(onTerminate, onValue));
  }

  const Cont._(this._run);

  /// Creates a [Cont] from a run function that accepts an observer.
  ///
  /// Constructs a continuation with guaranteed idempotence and exception catching.
  /// The run function receives an observer with `onValue` and `onTerminate` callbacks.
  /// The callbacks should be called as the last instruction in the run function
  /// or saved to be called later.
  ///
  /// - [run]: Function that executes the continuation and calls observer callbacks.
  static Cont<A> fromRun<A>(void Function(ContObserver<A> observer) run) {
    return Cont._((observer) {
      bool isDone = false;

      void guardedTerminate(List<ContError> errors) {
        if (isDone) {
          return;
        }
        isDone = true;
        observer.onTerminate([...errors]);
      }

      void guardedValue(A a) {
        if (isDone) {
          return;
        }
        isDone = true;
        observer.onValue(a);
      }

      try {
        run(ContObserver(guardedTerminate, guardedValue));
      } catch (error, st) {
        guardedTerminate([ContError(error, st)]);
      }
    });
  }

  /// Creates a [Cont] from a deferred continuation computation.
  ///
  /// Lazily evaluates a continuation-returning function. The inner [Cont] is
  /// not created until the outer one is executed.
  ///
  /// - [thunk]: Function that returns a [Cont] when called.
  static Cont<A> fromDeferred<A>(Cont<A> Function() thunk) {
    return Cont.fromRun((observer) {
      thunk().runWith(observer);
    });
  }

  /// Transforms the value inside a [Cont] using a pure function.
  ///
  /// Applies a function to the successful value of the continuation without
  /// affecting the termination case.
  ///
  /// - [f]: Transformation function to apply to the value.
  Cont<A2> map<A2>(A2 Function(A value) f) {
    return flatMap((a) {
      final a2 = f(a);
      return Cont.of(a2);
    });
  }

  /// Transforms the value inside a [Cont] using a zero-argument function.
  ///
  /// Similar to [map] but ignores the current value and computes a new one.
  ///
  /// - [f]: Zero-argument transformation function.
  Cont<A2> map0<A2>(A2 Function() f) {
    return map((_) {
      return f();
    });
  }

  /// Replaces the value inside a [Cont] with a constant.
  ///
  /// Discards the current value and replaces it with a fixed value.
  ///
  /// - [value]: The constant value to replace with.
  Cont<A2> mapTo<A2>(A2 value) {
    return map0(() {
      return value;
    });
  }

  /// Transforms the execution of the continuation using a natural transformation.
  ///
  /// Applies a function that wraps or modifies the underlying run behavior.
  /// This is useful for intercepting execution to add middleware-like behavior
  /// such as logging, timing, or modifying how observers receive callbacks.
  ///
  /// The transformation function receives both the original run function and
  /// the observer, allowing custom execution behavior to be injected.
  ///
  /// - [f]: A transformation function that receives the run function and observer,
  ///   and implements custom execution logic by calling the run function with the
  ///   observer at the appropriate time.
  ///
  /// Example:
  /// ```dart
  /// // Add logging around execution
  /// final logged = cont.hoist((run, observer) {
  ///   print('Starting execution');
  ///   run(observer);
  ///   print('Execution initiated');
  /// });
  /// ```
  Cont<A> hoist(void Function(void Function(ContObserver<A>) run, ContObserver<A> observer) f) {
    return Cont.fromRun((obs) {
      f(runWith, obs);
    });
  }

  /// Chains a [Cont]-returning function to create dependent computations.
  ///
  /// Monadic bind operation. Sequences continuations where the second depends
  /// on the result of the first.
  ///
  /// - [f]: Function that takes a value and returns a continuation.
  Cont<A2> flatMap<A2>(Cont<A2> Function(A value) f) {
    return Cont.fromRun((observer) {
      runWith(
        observer.copyUpdateOnValue((a) {
          try {
            final contA2 = f(a);
            contA2.runWith(observer);
          } catch (error, st) {
            observer.onTerminate([ContError(error, st)]);
          }
        }),
      );
    });
  }

  /// Chains a [Cont]-returning zero-argument function.
  ///
  /// Similar to [flatMap] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a continuation.
  Cont<A2> flatMap0<A2>(Cont<A2> Function() f) {
    return flatMap((_) {
      return f();
    });
  }

  /// Chains to a constant [Cont].
  ///
  /// Sequences to a fixed continuation, ignoring the current value.
  ///
  /// - [cont]: The continuation to chain to.
  Cont<A2> flatMapTo<A2>(Cont<A2> cont) {
    return flatMap0(() {
      return cont;
    });
  }

  /// Chains a side-effect continuation while preserving the original value.
  ///
  /// Executes a continuation for its side effects, then returns the original value.
  ///
  /// - [f]: Side-effect function that returns a continuation.
  Cont<A> flatTap<A2>(Cont<A2> Function(A value) f) {
    return flatMap((a) {
      return f(a).mapTo(a);
    });
  }

  /// Chains a zero-argument side-effect continuation.
  ///
  /// Similar to [flatTap] but with a zero-argument function.
  ///
  /// - [f]: Zero-argument side-effect function.
  Cont<A> flatTap0<A2>(Cont<A2> Function() f) {
    return flatTap((_) {
      return f();
    });
  }

  /// Chains to a constant side-effect continuation.
  ///
  /// Executes a fixed continuation for its side effects, preserving the original value.
  ///
  /// - [cont]: The side-effect continuation.
  Cont<A> flatTapTo<A2>(Cont<A2> cont) {
    return flatTap0(() {
      return cont;
    });
  }

  /// Chains and combines two continuation values.
  ///
  /// Sequences two continuations and combines their results using the provided function.
  ///
  /// - [f]: Function to produce the second continuation from the first value.
  /// - [combine]: Function to combine both values into a result.
  Cont<A3> flatMapZipWith<A2, A3>(Cont<A2> Function(A value) f, A3 Function(A a1, A2 a2) combine) {
    return flatMap((a1) {
      return f(a1).map((a2) {
        return combine(a1, a2);
      });
    });
  }

  /// Chains and combines with a zero-argument function.
  ///
  /// Similar to [flatMapZipWith] but the second continuation doesn't depend
  /// on the first value.
  ///
  /// - [f]: Zero-argument function to produce the second continuation.
  /// - [combine]: Function to combine both values into a result.
  Cont<A3> flatMapZipWith0<A2, A3>(Cont<A2> Function() f, A3 Function(A a1, A2 a2) combine) {
    return flatMapZipWith((_) {
      return f();
    }, combine);
  }

  /// Chains and combines with a constant continuation.
  ///
  /// Sequences to a fixed continuation and combines their results.
  ///
  /// - [other]: The second continuation.
  /// - [f]: Function to combine both values into a result.
  Cont<A3> flatMapZipWithTo<A2, A3>(Cont<A2> other, A3 Function(A a1, A2 a2) f) {
    return flatMapZipWith0(() {
      return other;
    }, f);
  }

  /// Executes a side-effect continuation in a fire-and-forget manner.
  ///
  /// Unlike [flatTap], this method does not wait for the side-effect to complete.
  /// The side-effect continuation is started immediately, and the original value
  /// is returned without delay. Any errors from the side-effect are silently ignored.
  ///
  /// - [f]: Function that takes the current value and returns a side-effect continuation.
  Cont<A> forkTap<A2>(Cont<A2> Function(A a) f) {
    return flatMap((a) {
      final contA2 = f(a); // this should not be inside try-catch block

      try {
        contA2.runWith(ContObserver.ignore());
      } catch (_) {
        // do nothing, if anything happens to side-effect, it's not
        // a concern of the forkTap
      }

      return Cont.of(a);
    });
  }

  /// Executes a zero-argument side-effect continuation in a fire-and-forget manner.
  ///
  /// Similar to [forkTap] but ignores the current value.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<A> forkTap0<A2>(Cont<A2> Function() f) {
    return forkTap((_) {
      return f();
    });
  }

  /// Executes a constant side-effect continuation in a fire-and-forget manner.
  ///
  /// Similar to [forkTap0] but takes a fixed continuation instead of a function.
  ///
  /// - [other]: The side-effect continuation to execute.
  Cont<A> forkTapTo<A2>(Cont<A2> other) {
    return forkTap0(() {
      return other;
    });
  }

  /// Runs a list of continuations sequentially and collects results.
  ///
  /// Executes continuations one by one, collecting all successful values.
  /// Terminates on first error. Uses stack-safe recursion to handle large lists.
  ///
  /// - [list]: List of continuations to execute sequentially.
  static Cont<List<A>> sequence<A>(List<Cont<A>> list) {
    final safeCopy0 = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      final safeCopy = List<Cont<A>>.from(safeCopy0);
      _stackSafeLoop<_Either<(int, List<A>), List<ContError>>, (int, List<A>), _Either<List<A>, List<ContError>>>(
        seed: _Value1((0, [])),
        keepRunningIf: (state) {
          switch (state) {
            case _Value1(value: final value):
              final (index, results) = value;
              if (index >= safeCopy.length) {
                return _StackSafeLoopPolicyStop(_Value1(results));
              }
              return _StackSafeLoopPolicyKeepRunning((index, results));
            case _Value2(value: final value):
              return _StackSafeLoopPolicyStop(_Value2(value));
          }
        },
        computation: (tuple, callback) {
          final (i, values) = tuple;
          final cont = safeCopy[i];
          try {
            cont.runWith(
              ContObserver(
                (errors) {
                  callback(_Value2([...errors]));
                },
                (a) {
                  callback(_Value1((i + 1, [...values, a])));
                },
                //
              ),
            );
          } catch (error, st) {
            callback(_Value2([ContError(error, st)]));
          }
        },
        escape: (triple) {
          switch (triple) {
            case _Value1(value: final results):
              observer.onValue(results);
              return;
            case _Value2(value: final errors):
              observer.onTerminate(errors);
              return;
          }
        },
        //
      );
    });
  }

  /// Provides a fallback continuation in case of termination.
  ///
  /// If the continuation terminates, executes the fallback. Accumulates
  /// errors from both attempts if the fallback also fails.
  ///
  /// - [f]: Function that receives errors and produces a fallback continuation.
  Cont<A> orElseWith(Cont<A> Function(List<ContError> errors) f) {
    return Cont.fromRun((observer) {
      runWith(
        observer.copyUpdateOnTerminate((errors) {
          try {
            f(errors).runWith(
              observer.copyUpdateOnTerminate((errors2) {
                observer.onTerminate([...errors, ...errors2]);
              }),
            );
          } catch (error, st) {
            observer.onTerminate([...errors, ContError(error, st)]);
          }
        }),
      );
    });
  }

  /// Provides a zero-argument fallback continuation.
  ///
  /// Similar to [orElseWith] but doesn't use the error information.
  ///
  /// - [f]: Zero-argument function that produces a fallback continuation.
  Cont<A> orElseWith0(Cont<A> Function() f) {
    return orElseWith((_) {
      return f();
    });
  }

  /// Provides a constant fallback continuation.
  ///
  /// If the continuation terminates, tries the fixed alternative.
  ///
  /// - [other]: The fallback continuation.
  Cont<A> orElse(Cont<A> other) {
    return orElseWith0(() {
      return other;
    });
  }

  /// Tries multiple continuations until one succeeds.
  ///
  /// Executes continuations one by one until one succeeds. Terminates only
  /// if all fail, accumulating all errors.
  ///
  /// - [list]: List of continuations to try sequentially.
  static Cont<A> orElseAll<A>(List<Cont<A>> list) {
    final List<Cont<A>> safeCopy0 = List<Cont<A>>.from(list);

    return Cont.fromRun((observer) {
      final safeCopy = List<Cont<A>>.from(safeCopy0);

      _stackSafeLoop<_Either<(int, List<ContError>), A>, (int, List<ContError>), _Either<List<ContError>, A>>(
        seed: _Value1((0, [])),
        keepRunningIf: (triple) {
          switch (triple) {
            case _Value1(value: final tuple):
              final (index, errors) = tuple;
              if (index >= safeCopy.length) {
                return _StackSafeLoopPolicyStop(_Value1(errors));
              }
              return _StackSafeLoopPolicyKeepRunning((index, errors));
            case _Value2(value: final a):
              return _StackSafeLoopPolicyStop(_Value2(a));
          }
        },
        computation: (tuple, callback) {
          final (index, errors) = tuple;
          final cont = safeCopy[index];

          try {
            cont.runWith(
              ContObserver(
                (errors2) {
                  callback(_Value1((index + 1, [...errors, ...errors2])));
                },
                (a) {
                  callback(_Value2(a));
                },
                //
              ),
            );
          } catch (error, st) {
            callback(_Value1((index + 1, [...errors, ContError(error, st)])));
          }
        },
        escape: (triple) {
          switch (triple) {
            case _Value1(value: final errors):
              observer.onTerminate([...errors]);
              return;
            case _Value2(value: final a):
              observer.onValue(a);
              return;
          }
        },
        //
      );
    });
  }

  /// Conditionally allows a value to pass through.
  ///
  /// If the predicate returns false, the continuation terminates without errors.
  /// Otherwise, passes the value through unchanged.
  ///
  /// - [f]: Predicate function to test the value.
  Cont<A> filter(bool Function(A value) f) {
    return flatMap((a) {
      if (!f(a)) {
        return Cont.terminate<A>();
      }

      return Cont.of(a);
    });
  }

  /// Creates a [Cont] that immediately succeeds with a value.
  ///
  /// Identity operation that wraps a pure value in a continuation context.
  ///
  /// - [value]: The value to wrap.
  static Cont<A> of<A>(A value) {
    return Cont.fromRun((observer) {
      observer.onValue(value);
    });
  }

  /// Creates a [Cont] that immediately terminates with optional errors.
  ///
  /// Creates a continuation that terminates without producing a value.
  /// Used to represent failure states.
  ///
  /// - [errors]: List of errors to terminate with. Defaults to an empty list.
  static Cont<A> terminate<A>([List<ContError> errors = const []]) {
    final safeCopyErrors0 = List<ContError>.from(errors);
    return Cont.fromRun((observer) {
      final safeCopyErrors = List<ContError>.from(safeCopyErrors0);
      observer.onTerminate(safeCopyErrors);
    });
  }

  /// Runs two continuations in parallel and combines their results.
  ///
  /// Executes both continuations concurrently. Succeeds when both succeed,
  /// terminates if either fails.
  ///
  /// - [left]: First continuation.
  /// - [right]: Second continuation.
  /// - [f]: Function to combine results from both continuations.
  static Cont<C> both<A, B, C>(
    Cont<A> left,
    Cont<B> right,
    C Function(A a, B b) f,
    //
  ) {
    return Cont.fromRun((observer) {
      bool isOneFail = false;
      bool isOneValue = false;

      A? outerA;
      B? outerB;
      final List<ContError> resultErrors = [];

      void handleValue() {
        if (isOneFail) {
          return;
        }

        if (!isOneValue) {
          isOneValue = true;
          return;
        }

        try {
          final c = f(outerA as A, outerB as B);
          observer.onValue(c);
        } catch (error, st) {
          observer.onTerminate([ContError(error, st)]);
        }
      }

      void handleTerminate(void Function() codeToUpdate) {
        if (isOneFail) {
          return;
        }
        isOneFail = true;
        codeToUpdate();
        observer.onTerminate(resultErrors);
      }

      try {
        left.runWith(
          ContObserver(
            (errors) {
              handleTerminate(() {
                resultErrors.insertAll(0, errors);
              });
            },
            (a) {
              // strict order must be followed
              outerA = a;
              handleValue();
            },
          ),
        );
      } catch (error, st) {
        handleTerminate(() {
          resultErrors.insert(0, ContError(error, st));
        });
      }

      try {
        right.runWith(
          ContObserver(
            (errors) {
              handleTerminate(() {
                resultErrors.addAll(errors);
              });
            },
            (b) {
              // strict order must be followed
              outerB = b;
              handleValue();
            },
          ),
        );
      } catch (error, st) {
        handleTerminate(() {
          resultErrors.add(ContError(error, st));
        });
      }
    });
  }

  /// Instance method for combining with another continuation in parallel.
  ///
  /// Convenient instance method wrapper for [Cont.both].
  ///
  /// - [other]: The other continuation to run in parallel.
  /// - [f]: Function to combine results from both continuations.
  Cont<C> and<B, C>(
    Cont<B> other,
    C Function(A a, B b) f,
    //
  ) {
    return Cont.both(this, other, f);
  }

  /// Runs multiple continuations in parallel and collects all results.
  ///
  /// Executes all continuations concurrently. Succeeds only when all succeed,
  /// preserving result order.
  ///
  /// - [list]: List of continuations to execute in parallel.
  static Cont<List<A>> all<A>(List<Cont<A>> list) {
    final safeCopy0 = List<Cont<A>>.from(list);

    return Cont.fromRun((observer) {
      final safeCopy = List<Cont<A>>.from(safeCopy0);

      if (safeCopy.isEmpty) {
        observer.onValue(<A>[]);
        return;
      }

      bool isDone = false;
      final results = List<A?>.filled(safeCopy.length, null);

      int amountOfFinishedContinuations = 0;

      void handleNoneOrFail(List<ContError> errors) {
        if (isDone) {
          return;
        }
        isDone = true;

        observer.onTerminate(errors);
      }

      for (final (i, cont) in safeCopy.indexed) {
        try {
          cont.runWith(
            ContObserver(
              (errors) {
                handleNoneOrFail([...errors]); // defensive copy
              },
              (a) {
                if (isDone) {
                  return;
                }

                results[i] = a;
                amountOfFinishedContinuations += 1;

                if (amountOfFinishedContinuations < safeCopy.length) {
                  return;
                }

                observer.onValue(results.cast<A>());
              },
            ),
          );
        } catch (error, st) {
          handleNoneOrFail([ContError(error, st)]);
        }
      }
    });
  }

  /// Races two continuations, returning the first successful value.
  ///
  /// Returns the result of whichever continuation succeeds first.
  /// Terminates only if both fail, accumulating all errors.
  ///
  /// - [left]: First continuation to race.
  /// - [right]: Second continuation to race.
  static Cont<A> raceForWinner<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((observer) {
      bool isOneFailed = false;
      final List<ContError> resultErrors = [];
      bool isDone = false;

      void handleNoneOrFail(void Function() codeToUpdateState) {
        if (isOneFailed) {
          codeToUpdateState();

          observer.onTerminate(resultErrors);
          return;
        }
        isOneFailed = true;

        codeToUpdateState();
      }

      ContObserver<A> makeObserver(void Function(List<ContError> errors) codeToUpdateState) {
        return ContObserver(
          (errors) {
            if (isDone) {
              return;
            }
            handleNoneOrFail(() {
              codeToUpdateState([...errors]);
            });
          },
          (a) {
            if (isDone) {
              return;
            }
            isDone = true;
            observer.onValue(a);
          },
        );
      }

      try {
        left.runWith(
          makeObserver((errors) {
            resultErrors.insertAll(0, errors);
          }),
        );
      } catch (error, st) {
        handleNoneOrFail(() {
          resultErrors.insert(0, ContError(error, st));
        });
      }

      try {
        right.runWith(
          makeObserver((errors) {
            resultErrors.addAll(errors);
          }),
        );
      } catch (error, st) {
        handleNoneOrFail(() {
          resultErrors.add(ContError(error, st));
        });
      }
    });
  }

  /// Races two continuations, returning the value from the last to complete.
  ///
  /// Waits for both to complete, returns the slower one's value. Useful for
  /// timeout scenarios. Terminates if both fail.
  ///
  /// - [left]: First continuation.
  /// - [right]: Second continuation.
  static Cont<A> raceForLoser<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((observer) {
      bool isFirstComputed = false;

      final List<ContError> resultErrors = [];

      bool isResultAvailable = false;
      A? result;

      void handleNoneOrFail(void Function() codeToUpdateState) {
        if (!isFirstComputed) {
          isFirstComputed = true;
          codeToUpdateState();
          return;
        }

        if (isResultAvailable) {
          observer.onValue(result as A);
          return;
        }

        codeToUpdateState();

        observer.onTerminate(resultErrors);
      }

      ContObserver<A> makeObserver(void Function(List<ContError> errors) codeToUpdateState) {
        return ContObserver(
          (errors) {
            handleNoneOrFail(() {
              codeToUpdateState(errors);
            });
          },
          (a) {
            if (isFirstComputed) {
              observer.onValue(a);
              return;
            }
            result = a;
            isFirstComputed = true;
            isResultAvailable = true;
          },
        );
      }

      try {
        left.runWith(
          makeObserver((errors) {
            resultErrors.insertAll(0, errors);
          }),
        );
      } catch (error, st) {
        handleNoneOrFail(() {
          resultErrors.insert(0, ContError(error, st));
        });
      }

      try {
        right.runWith(
          makeObserver((errors) {
            resultErrors.addAll(errors);
          }),
        );
      } catch (error, st) {
        handleNoneOrFail(() {
          resultErrors.add(ContError(error, st));
        });
      }
    });
  }

  /// Instance method to race with another continuation for the first success.
  ///
  /// Convenient instance method wrapper for [Cont.raceForWinner].
  ///
  /// - [other]: The other continuation to race with.
  Cont<A> raceForWinnerWith(Cont<A> other) {
    return Cont.raceForWinner(this, other);
  }

  /// Instance method to race for loser with another continuation.
  ///
  /// Convenient instance method wrapper for [Cont.raceForLoser].
  ///
  /// - [other]: The other continuation to race with.
  Cont<A> raceForLoserWith(Cont<A> other) {
    return Cont.raceForLoser(this, other);
  }

  /// Races multiple continuations for the first success.
  ///
  /// Returns the first successful result. Terminates only when all fail,
  /// accumulating all errors.
  ///
  /// - [list]: List of continuations to race.
  static Cont<A> raceForWinnerAll<A>(List<Cont<A>> list) {
    final list0 = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      final list = List<Cont<A>>.from(list0);
      if (list.isEmpty) {
        observer.onTerminate();
        return;
      }

      final List<List<ContError>> resultOfErrors = List.generate(list.length, (_) {
        return [];
      });

      bool isWinnerFound = false;
      int numberOfFinished = 0;

      void handleTerminate(int index, List<ContError> errors) {
        if (isWinnerFound) {
          return;
        }
        numberOfFinished += 1;

        resultOfErrors[index] = errors;

        if (numberOfFinished < list.length) {
          return;
        }

        final flattened = resultOfErrors.expand((list) {
          return list;
        }).toList();

        observer.onTerminate(flattened);
      }

      for (int i = 0; i < list.length; i++) {
        final cont = list[i];
        try {
          cont.runWith(
            ContObserver(
              (errors) {
                handleTerminate(i, [...errors]); // defensive copy
              },
              (a) {
                if (isWinnerFound) {
                  return;
                }
                isWinnerFound = true;
                observer.onValue(a);
              },
            ),
          );
        } catch (error, st) {
          handleTerminate(i, [ContError(error, st)]);
        }
      }
    });
  }

  /// Races multiple continuations for the last to complete.
  ///
  /// Returns the result of the last continuation to finish successfully.
  /// Terminates only if all fail.
  ///
  /// - [list]: List of continuations to race.
  static Cont<A> raceForLoserAll<A>(List<Cont<A>> list) {
    final list0 = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      final list = List<Cont<A>>.from(list0);
      if (list.isEmpty) {
        observer.onTerminate();
        return;
      }

      final List<List<ContError>> resultErrors = List.generate(list.length, (_) {
        return [];
      });

      bool isItemFoundAvailable = false;
      A? lastValue;
      int numberOfFinished = 0;

      void incrementFinishedAndCheckExit() {
        numberOfFinished += 1;
        if (numberOfFinished < list.length) {
          return;
        }

        if (isItemFoundAvailable) {
          observer.onValue(lastValue as A);
          return;
        }

        final flattened = resultErrors.expand((list) {
          return list;
        }).toList();

        observer.onTerminate(flattened);
      }

      for (int i = 0; i < list.length; i++) {
        final cont = list[i];

        try {
          cont.runWith(
            ContObserver(
              (errors) {
                resultErrors[i] = [...errors];
                incrementFinishedAndCheckExit();
              },
              (a) {
                lastValue = a;
                isItemFoundAvailable = true;

                incrementFinishedAndCheckExit();
              },
            ),
          );
        } catch (error, st) {
          resultErrors[i] = [ContError(error, st)];
          incrementFinishedAndCheckExit();
        }
      }
    });
  }

  /// Manages resource lifecycle with guaranteed cleanup.
  ///
  /// The bracket pattern ensures that a resource is properly released after use,
  /// even if an error occurs during the [use] phase. This is the functional
  /// equivalent of try-with-resources or using statements.
  ///
  /// The execution order is:
  /// 1. [acquire] - Obtain the resource
  /// 2. [use] - Use the resource to produce a value
  /// 3. [release] - Release the resource (always runs, even if [use] fails)
  ///
  /// Error handling behavior:
  /// - If [use] succeeds and [release] succeeds: returns the value from [use]
  /// - If [use] succeeds and [release] fails: terminates with release errors
  /// - If [use] fails and [release] succeeds: terminates with use errors
  /// - If [use] fails and [release] fails: terminates with both errors combined
  ///
  /// Example:
  /// ```dart
  /// final result = Cont.bracket<File, String>(
  ///   acquire: openFile('data.txt'),           // acquire
  ///   release: (file) => closeFile(file),      // release
  ///   use: (file) => readContents(file),   // use
  /// );
  /// ```
  static Cont<A> bracket<R, A>({
    required Cont<R> acquire,
    required Cont<()> Function(R resource) release,
    required Cont<A> Function(R resource) use,
    //
  }) {
    return acquire.flatMap((resource) {
      return Cont.fromDeferred(() {
        Cont<()> doProperRelease() {
          try {
            return release(resource);
          } catch (error, st) {
            return Cont.terminate([ContError(error, st)]);
          }
        }

        try {
          final mainCont = use(resource);
          return mainCont
              .orElseWith((errors) {
                return doProperRelease()
                    .orElseWith((errors2) {
                      return Cont.terminate([...errors, ...errors2]);
                    })
                    .flatMap0(() {
                      return Cont.terminate(errors);
                    });
              })
              .flatMap((a) {
                return doProperRelease().mapTo(a);
              });
        } catch (error, st) {
          return doProperRelease()
              .orElseWith((errors2) {
                return Cont.terminate([ContError(error, st), ...errors2]);
              })
              .flatMap0(() {
                return Cont.terminate([ContError(error, st)]);
              });
        }
      });
    });
  }
}

/// Extension providing flatten operation for nested continuations.
extension ContFlattenExtension<A> on Cont<Cont<A>> {
  /// Flattens a nested [Cont] structure.
  ///
  /// Converts `Cont<Cont<A>>` to `Cont<A>`. Equivalent to `flatMap((contA) => contA)`.
  Cont<A> flatten() {
    return flatMap((contA) => contA);
  }
}

void _stackSafeLoop<A, B, C>({
  required A seed,
  required _StackSafeLoopPolicy<B, C> Function(A) keepRunningIf,
  required void Function(B, void Function(A)) computation,
  required void Function(C) escape,
  //
}) {
  var mutableSeedCopy = seed;

  while (true) {
    final policy = keepRunningIf(mutableSeedCopy);

    switch (policy) {
      case _StackSafeLoopPolicyStop<B, C>(value: final value):
        escape(value);
        return;
      case _StackSafeLoopPolicyKeepRunning<B, C>():
        break;
    }

    bool isSchedulerUsed = false;
    bool isSync1 = true;
    bool isSync2 = false;

    computation(policy.value, (updatedA) {
      if (isSchedulerUsed) {
        return;
      }

      isSchedulerUsed = true;

      if (isSync1) {
        isSync2 = true;
        mutableSeedCopy = updatedA;
        return;
      }
      // not sync

      _stackSafeLoop(
        seed: updatedA,
        keepRunningIf: keepRunningIf,
        computation: computation,
        escape: escape,
        //
      );
    });
    isSync1 = false;
    if (isSync2) {
      continue;
    } else {
      break;
    }
  }
}

sealed class _Either<A, B> {
  const _Either();
}

final class _Value1<A, B> extends _Either<A, B> {
  final A value;

  const _Value1(this.value);
}

final class _Value2<A, B> extends _Either<A, B> {
  final B value;

  const _Value2(this.value);
}

sealed class _StackSafeLoopPolicy<A, B> {
  const _StackSafeLoopPolicy();
}

final class _StackSafeLoopPolicyKeepRunning<A, B> extends _StackSafeLoopPolicy<A, B> {
  final A value;

  const _StackSafeLoopPolicyKeepRunning(this.value);
}

final class _StackSafeLoopPolicyStop<A, B> extends _StackSafeLoopPolicy<A, B> {
  final B value;

  const _StackSafeLoopPolicyStop(this.value);
}
