import 'package:jerelo/src/cont_error.dart';
import 'package:jerelo/src/cont_observer.dart';
import 'package:jerelo/src/cont_scheduler.dart';
import 'package:jerelo/src/cont_signal.dart';
import 'package:jerelo/src/ref_commit.dart';

final class Cont<A> {
  final void Function(ContObserver<A> observer) subscribe;

  void run({
    required void Function(ContError, ContSignal) onFatal,
    void Function() onNone = _doNothing,
    void Function(ContError, List<ContError>) onFail = _ignore2,
    void Function(A value) onSome = _ignore1,
  }) {
    subscribe(ContObserver(onFatal, onNone, onFail, onSome));
  }

  // ! constructor must not be called by anything other than "Cont.fromRun" !
  const Cont._(this.subscribe);

  // onNone and some should be called as a last instruction in "run" or saved to be called later
  static Cont<A> fromRun<A>(void Function(ContObserver<A> observer) run) {
    // guarantees idempotence
    // guarantees to catch throws
    return Cont._((observer) {
      final runner = _IdempotentRunner();

      void handleUnrecoverableFailure(Object error, StackTrace st, ContSignal signal) {
        try {
          observer.onFatal(ContError(error, st), signal);
        } catch (error, st) {
          // we schedule it in microtask to ensure that
          // there is no try-catch around it and it does fail
          // !best-effort crash unless a Zone catches it.!
          Future.microtask(() {
            Error.throwWithStackTrace(error, st);
          });
        }
      }

      bool guardedFail(ContError error, List<ContError> errors) {
        return runner.runIfNotDone(() {
          try {
            observer.onFail(error, errors);
          } catch (error, st) {
            handleUnrecoverableFailure(error, st, ContSignal.onFail);
          }
        });
      }

      try {
        run(
          ContObserver(
            (error, signal) {
              handleUnrecoverableFailure(error.error, error.st, signal);
            },
            () {
              runner.runIfNotDone(() {
                try {
                  observer.onNone();
                } catch (error, st) {
                  handleUnrecoverableFailure(error, st, ContSignal.onNone);
                }
              });
            },
            guardedFail,
            (a) {
              runner.runIfNotDone(() {
                try {
                  observer.onSome(a);
                } catch (error, st) {
                  handleUnrecoverableFailure(error, st, ContSignal.onSome);
                }
              });
            },
          ),
        );
      } catch (error, st) {
        guardedFail(ContError(error, st), []);
      }
    });
  }

  static Cont<A> fromDeferred<A>(Cont<A> Function() thunk) {
    return Cont.fromRun((observer) {
      thunk().subscribe(observer);
    });
  }

  Cont<A2> flatMap<A2>(Cont<A2> Function(A value) f) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: observer.onFail,
        onSome: (a) {
          try {
            final contA2 = f(a);
            contA2.subscribe(observer);
          } catch (error, st) {
            observer.onFail(ContError(error, st), []);
          }
        },
      );
    });
  }

  Cont<A> catchEmpty(Cont<A> Function() f) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: () {
          try {
            final contA = f();
            contA.subscribe(observer);
          } catch (error, st) {
            observer.onFail(ContError(error, st), []);
          }
        },
        onFail: observer.onFail,
        onSome: observer.onSome,
      );
    });
  }

  Cont<A> catchError(Cont<A> Function(ContError error, List<ContError> errors) f) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: (error, errors) {
          try {
            final recoveryCont = f(error, errors);
            recoveryCont.subscribe(observer);
          } catch (error2, st) {
            observer.onFail(error, [...errors, ContError(error2, st)]);
          }
        },
        onSome: observer.onSome,
      );
    });
  }

  Cont<A2> then<A2>(Cont<A2> cont) {
    return flatMap((_) {
      return cont;
    });
  }

  static Cont<A> fromThunk<A>(A Function() thunk) {
    return Cont.fromRun((observer) {
      final a = thunk();
      observer.onSome(a);
    });
  }

  static Cont<()> fromProcedure(void Function() procedure) {
    return Cont.fromRun((observer) {
      procedure();
      observer.onSome(());
    });
  }

  static Cont<A> of<A>(A value) {
    return Cont.fromThunk(() {
      return value;
    });
  }

  static Cont<()> unit() {
    return Cont.of(());
  }

  static Cont<A> empty<A>() {
    return Cont.fromRun((observer) {
      observer.onNone();
    });
  }

  static Cont<Never> zero() {
    return empty<Never>();
  }

  static Cont<A> raise<A>(ContError error, [List<ContError> errors = const []]) {
    final safeCopy = List<ContError>.from(errors);
    return Cont.fromRun((observer) {
      observer.onFail(error, safeCopy);
    });
  }

  static Cont<Never> panic(ContError error, [List<ContError> errors = const []]) {
    return Cont.raise<Never>(error, errors);
  }

  Cont<A2> map<A2>(A2 Function(A value) f) {
    return flatMap((a) {
      final a2 = f(a);
      return Cont.of(a2);
    });
  }

  Cont<A2> map0<A2>(A2 Function() f) {
    return map((_) {
      return f();
    });
  }

  Cont<C> zipSequentially<A2, C>(Cont<A2> other, C Function(A a, A2 a2) f) {
    return flatMap((a) {
      return other.map((a2) {
        return f(a, a2);
      });
    });
  }

  static Cont<List<A>> zipAllSequentially<A>(List<Cont<A>> list) {
    final safeCopy = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      final List<A> result = [];
      void add(int i) {
        if (i >= safeCopy.length) {
          observer.onSome(result);
          return;
        }

        final cont = safeCopy[i];
        cont.run(
          onFatal: observer.onFatal,
          onNone: observer.onNone,
          onFail: observer.onFail,
          onSome: (a) {
            result.add(a);
            add(i + 1);
          },
        );
      }

      add(0);
    });
  }

  Cont<C> zipConcurrently<A2, C>(Cont<A2> other, C Function(A a, A2 a2) f) {
    return Cont.fromRun((observer) {
      bool isOneFail = false;
      bool isOneSome = false;

      A? outerA;
      A2? outerA2;
      final List<ContError> resultErrors = [];

      void handleSome() {
        if (!isOneSome && !isOneFail) {
          isOneSome = true;
          return;
        }

        if (isOneSome) {
          try {
            final c = f(outerA as A, outerA2 as A2);
            observer.onSome(c);
          } catch (error, st) {
            observer.onFail(ContError(error, st), []);
            return;
          }
        } else {
          if (resultErrors.isEmpty) {
            observer.onNone();
          } else {
            observer.onFail(resultErrors.first, resultErrors.skip(1).toList());
          }
        }
      }

      void handleNoneAndFail() {
        if (!isOneSome && !isOneFail) {
          isOneFail = true;
          return;
        }

        if (resultErrors.isEmpty) {
          observer.onNone();
        } else {
          observer.onFail(resultErrors.first, resultErrors.skip(1).toList());
        }
      }

      run(
        onFatal: observer.onFatal,
        onNone: () {
          handleNoneAndFail();
        },
        onFail: (error, errors) {
          // strict order must be followed
          resultErrors.insert(0, error);
          resultErrors.insertAll(1, errors);
          handleNoneAndFail();
        },
        onSome: (a) {
          // strict order must be followed
          outerA = a;
          handleSome();
        },
      );

      other.run(
        onFatal: observer.onFatal,
        onNone: () {
          handleNoneAndFail();
        },
        onFail: (error, errors) {
          // strict order must be followed
          resultErrors.add(error);
          resultErrors.addAll(errors);
          handleNoneAndFail();
        },
        onSome: (a2) {
          // strict order must be followed
          outerA2 = a2;
          handleSome();
        },
      );
    });
  }

  static Cont<List<A>> zipAllConcurrently<A>(List<Cont<A>> list) {
    final safeCopy = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      if (safeCopy.isEmpty) {
        observer.onSome(<A>[]);
        return;
      }

      final results = List<A?>.filled(safeCopy.length, null);
      final resultErrors = List<List<ContError>>.generate(safeCopy.length, (_) {
        return [];
      });

      bool isFailed = false;
      int amountOfFinishedContinuations = 0;

      void handleNoneOrFail(int index, List<ContError> errors) {
        amountOfFinishedContinuations += 1;
        isFailed = true;

        resultErrors[index] = errors;

        if (amountOfFinishedContinuations < safeCopy.length) {
          // we haven't computed all Continuations
          return;
        }

        final flattened = resultErrors.expand((list) {
          return list;
        }).toList();

        if (flattened.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(flattened.first, flattened.skip(1).toList());
      }

      for (final (i, cont) in safeCopy.indexed) {
        final index = i; // important
        cont.run(
          onFatal: observer.onFatal,
          onNone: () {
            handleNoneOrFail(index, []);
          },
          onFail: (error, errors) {
            handleNoneOrFail(index, [error, ...errors]);
          },
          onSome: (a) {
            amountOfFinishedContinuations += 1;
            if (isFailed) {
              if (amountOfFinishedContinuations >= safeCopy.length) {
                final flattened = resultErrors.expand((list) {
                  return list;
                }).toList();

                if (flattened.isEmpty) {
                  observer.onNone();
                } else {
                  observer.onFail(flattened.first, flattened.skip(1).toList());
                }
              }
              return;
            }
            results[index] = a;
            if (amountOfFinishedContinuations >= safeCopy.length) {
              observer.onSome(results.cast<A>());
            }
          },
        );
      }
    });
  }

  // always returns non-none and non-fail winner (first value)
  Cont<C> racePickWinner<A2, C>(Cont<A2> other, C Function(A a) lf, C Function(A2 a2) rf) {
    return Cont.fromRun((observer) {
      final runner = _IdempotentRunner();

      bool isOneFailed = false;
      final List<ContError> resultErrors = [];

      void handleNoneOrFail(void Function() codeToUpdateState) {
        if (isOneFailed) {
          codeToUpdateState();

          if (resultErrors.isEmpty) {
            observer.onNone();
            return;
          }

          observer.onFail(resultErrors.first, resultErrors.skip(1).toList());
          return;
        }
        isOneFailed = true;

        codeToUpdateState();
      }

      run(
        onFatal: observer.onFatal,
        onNone: () {
          handleNoneOrFail(() {});
        },
        onFail: (error, errors) {
          handleNoneOrFail(() {
            resultErrors.insert(0, error);
            resultErrors.insertAll(1, errors);
          });
        },
        onSome: (a) {
          try {
            final result = lf(a);
            runner.runIfNotDone(() {
              observer.onSome(result);
            });
          } catch (error, st) {
            handleNoneOrFail(() {
              resultErrors.insert(0, ContError(error, st));
            });
          }
        },
      );

      other.run(
        onFatal: observer.onFatal,
        onNone: () {
          handleNoneOrFail(() {});
        },
        onFail: (error, errors) {
          handleNoneOrFail(() {
            resultErrors.add(error);
            resultErrors.addAll(errors);
          });
        },
        onSome: (a2) {
          try {
            final result = rf(a2);
            runner.runIfNotDone(() {
              observer.onSome(result);
            });
          } catch (error, st) {
            handleNoneOrFail(() {
              resultErrors.add(ContError(error, st));
            });
          }
        },
      );
    });
  }

  Cont<A> racePickWinnerSame(Cont<A> other) {
    return racePickWinner(other, _idfunc<A>, _idfunc<A>);
  }

  static Cont<(int, A)> raceAllPickWinnerTagged<A>(List<Cont<A>> list) {
    final safeCopy = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      if (safeCopy.isEmpty) {
        observer.onNone();
        return;
      }

      final List<List<ContError>> resultOfErrors = List.generate(safeCopy.length, (_) {
        return [];
      });

      bool isWinnerFound = false;
      int numberOfFinished = 0;

      void handleNoneAndFail(int index, List<ContError> errors) {
        if (isWinnerFound) {
          return;
        }
        numberOfFinished += 1;

        resultOfErrors[index] = errors;

        if (numberOfFinished < safeCopy.length) {
          return;
        }

        final flattened = resultOfErrors.expand((list) {
          return list;
        }).toList();

        if (flattened.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(flattened.first, flattened.skip(1).toList());
      }

      for (int i = 0; i < safeCopy.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = safeCopy[i];
        cont.run(
          onFatal: observer.onFatal,
          onNone: () {
            handleNoneAndFail(index, []);
          },
          onFail: (error, errors) {
            handleNoneAndFail(index, [error, ...errors]);
          },
          onSome: (a) {
            if (isWinnerFound) {
              return;
            }
            isWinnerFound = true;
            observer.onSome((index, a));
          },
        );
      }
    });
  }

  static Cont<A> raceAllPickWinner<A>(List<Cont<A>> list) {
    return raceAllPickWinnerTagged(list).map((tuple) {
      return tuple.$2;
    });
  }

  // always returns non-onNone and non-fail loser (last value)
  Cont<C> racePickLoser<A2, C>(Cont<A2> other, C Function(A a) lf, C Function(A2 a2) rf) {
    return Cont.fromRun((observer) {
      bool isFirstComputed = false;

      final List<ContError> resultErrors = [];

      bool isResultAvailable = false;
      C? result;

      void handleNoneOrFail(void Function() codeToUpdateState) {
        if (!isFirstComputed) {
          isFirstComputed = true;
          codeToUpdateState();
          return;
        }

        if (isResultAvailable) {
          observer.onSome(result as C);
          return;
        }

        codeToUpdateState();

        if (resultErrors.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(resultErrors.first, resultErrors.skip(1).toList());
      }

      run(
        onFatal: observer.onFatal,
        onNone: () {
          handleNoneOrFail(() {});
        },
        onFail: (error, errors) {
          handleNoneOrFail(() {
            resultErrors.insert(0, error);
            resultErrors.insertAll(1, errors);
          });
        },
        onSome: (a) {
          if (isFirstComputed) {
            try {
              final result = lf(a);
              observer.onSome(result);
            } catch (error, st) {
              if (isResultAvailable) {
                observer.onSome(result as C);
              } else {
                handleNoneOrFail(() {
                  resultErrors.insert(0, ContError(error, st));
                });
              }
            }
            return;
          }

          try {
            result = lf(a);
            isFirstComputed = true;
            isResultAvailable = true;
          } catch (error, st) {
            handleNoneOrFail(() {
              resultErrors.insert(0, ContError(error, st));
            });
          }
        },
      );

      other.run(
        onFatal: observer.onFatal,
        onNone: () {
          handleNoneOrFail(() {});
        },
        onFail: (error, errors) {
          handleNoneOrFail(() {
            resultErrors.add(error);
            resultErrors.addAll(errors);
          });
        },
        onSome: (a2) {
          if (isFirstComputed) {
            try {
              final result = rf(a2);
              observer.onSome(result);
            } catch (error, st) {
              handleNoneOrFail(() {
                resultErrors.add(ContError(error, st));
              });
            }
            return;
          }

          try {
            result = rf(a2);
            isFirstComputed = true;
            isResultAvailable = true;
          } catch (error, st) {
            handleNoneOrFail(() {
              resultErrors.add(ContError(error, st));
            });
          }
        },
      );
    });
  }

  Cont<A> racePickLoserSame(Cont<A> other) {
    return racePickLoser(other, _idfunc<A>, _idfunc<A>);
  }

  static Cont<(int, A)> raceAllPickLoserTagged<A>(List<Cont<A>> list) {
    final safeCopy = List<Cont<A>>.from(list);
    return Cont.fromRun((observer) {
      if (safeCopy.isEmpty) {
        observer.onNone();
        return;
      }

      final List<List<ContError>> resultErrors = List.generate(safeCopy.length, (_) {
        return [];
      });

      int lastValueIndex = -1;
      A? lastValue;
      int numberOfFinished = 0;

      void incrementFinishedAndCheckExit() {
        numberOfFinished += 1;
        if (numberOfFinished < safeCopy.length) {
          return;
        }

        if (lastValueIndex != -1) {
          // an element is there
          observer.onSome((lastValueIndex, lastValue as A));
          return;
        }

        final flattened = resultErrors.expand((list) {
          return list;
        }).toList();

        if (flattened.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(flattened.first, flattened.skip(1).toList());
      }

      for (int i = 0; i < safeCopy.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = safeCopy[i];

        cont.run(
          onFatal: observer.onFatal,
          onNone: () {
            incrementFinishedAndCheckExit();
          },
          onFail: (error, errors) {
            resultErrors[index] = [error, ...errors];
            incrementFinishedAndCheckExit();
          },
          onSome: (a) {
            lastValue = a;
            lastValueIndex = index;

            incrementFinishedAndCheckExit();
          },
        );
      }
    });
  }

  static Cont<A> raceAllPickLoser<A>(List<Cont<A>> list) {
    return raceAllPickLoserTagged(list).map((tuple) {
      return tuple.$2;
    });
  }

  Cont<C> orElse<A2, C>(Cont<A2> other, C Function(A a) lf, C Function(A2 a2) rf) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: () {
          other.run(
            onFatal: observer.onFatal,
            onNone: observer.onNone,
            onFail: observer.onFail,
            onSome: (a2) {
              try {
                final result = rf(a2);
                observer.onSome(result);
              } catch (error, st) {
                observer.onFail(ContError(error, st), []);
              }
            },
          );
        },
        onFail: (error, errors) {
          other.run(
            onFatal: observer.onFatal,
            onNone: () {
              observer.onFail(error, errors);
            },
            onFail: (error2, errors2) {
              observer.onFail(error, [...errors, error2, ...errors2]);
            },
            onSome: (a2) {
              try {
                final result = rf(a2);
                observer.onSome(result);
              } catch (error, st) {
                observer.onFail(ContError(error, st), []);
              }
            },
          );
        },
        onSome: (a) {
          try {
            final result = lf(a);
            observer.onSome(result);
          } catch (error, st) {
            observer.onFail(ContError(error, st), []);
          }
        },
      );
    });
  }

  Cont<A> orElseSame(Cont<A> other) {
    return orElse(other, _idfunc<A>, _idfunc<A>);
  }

  static Cont<(int, A)> firstSuccessTagged<A>(List<Cont<A>> list) {
    return list.indexed.fold<Cont<(int, A)>>(Cont.empty<(int, A)>(), (accumulator, element) {
      final (index, cont) = element;
      final indexedCont = cont.map((a) {
        return (index, a);
      });

      return accumulator.orElseSame(indexedCont);
    });
  }

  static Cont<A> firstSuccess<A>(List<Cont<A>> list) {
    return firstSuccessTagged(list).map((tuple) {
      return tuple.$2;
    });
  }

  Cont<A> doOnNone(void Function() f) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: () {
          try {
            f();
          } catch (_) {
            // "f" is side effect. the user of "doOnNone" is responsible for making
            // sure that errors are caught and logged
            // the runtime crashes of "f" should not affect the main flow
          }
          observer.onNone();
        },
        onFail: observer.onFail,
        onSome: observer.onSome,
      );
    });
  }

  Cont<A> doOnFail(void Function(ContError error, List<ContError> errors) f) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: (error, errors) {
          try {
            f(error, errors);
          } catch (_) {
            // "f" is side effect. the user of "doOnFail" is responsible for making
            // sure that errors are caught and logged
            // the runtime crashes of "f" should not affect the main flow
          }
          observer.onFail(error, errors);
        },
        onSome: observer.onSome,
      );
    });
  }

  Cont<A> doOnSome(void Function(A a) f) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: observer.onFail,
        onSome: (a) {
          try {
            f(a);
          } catch (_) {
            // "f" is side effect. the user of "doOnNone" is responsible for making
            // sure that errors are caught and logged
            // the runtime crashes of "f" should not affect the main flow
          }
          observer.onSome(a);
        },
      );
    });
  }

  Cont<A> doOnRun(void Function() f) {
    return Cont.fromRun((observer) {
      try {
        f();
      } catch (_) {
        // "f" is side effect. the user of "doOnNone" is responsible for making
        // sure that errors are caught and logged
        // the runtime crashes of "f" should not affect the main flow
      }
      subscribe(observer);
    });
  }

  Cont<A> runOn(ContScheduler scheduler) {
    return Cont.fromRun((observer) {
      scheduler.run(() {
        subscribe(observer);
      });
    });
  }

  Cont<A> noneOn(ContScheduler scheduler) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: () {
          scheduler.run(observer.onNone);
        },
        onFail: observer.onFail,
        onSome: observer.onSome,
      );
    });
  }

  Cont<A> failOn(ContScheduler scheduler) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: (error, errors) {
          scheduler.run(() {
            observer.onFail(error, errors);
          });
        },
        onSome: observer.onSome,
      );
    });
  }

  Cont<A> someOn(ContScheduler scheduler) {
    return Cont.fromRun((observer) {
      run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: observer.onFail,
        onSome: (a) {
          scheduler.run(() {
            observer.onSome(a);
          });
        },
      );
    });
  }

  Cont<A> consumeOn(ContScheduler scheduler) {
    return noneOn(scheduler).failOn(scheduler).someOn(scheduler);
  }

  Cont<A> scheduleOn(ContScheduler scheduler) {
    return runOn(scheduler).consumeOn(scheduler);
  }

  Cont<A> filter(bool Function(A value) predicate) {
    return flatMap((a) {
      final isValid = predicate(a);
      if (isValid) {
        return Cont.of(a);
      } else {
        return Cont.empty();
      }
    });
  }

  static Cont<A> withRef<S, A>(
    S initial,
    Cont<A> Function(Ref<S> ref) use,
    Cont<Never> Function(Ref<S> ref) release,
    //
  ) {
    return Cont.fromDeferred(() {
      final ref = Ref._(initial);

      Cont<A> doProperRelease(List<ContError> errors) {
        try {
          final releaseCont = release(ref);
          return releaseCont
              .catchEmpty(() {
                if (errors.isNotEmpty) {
                  return Cont.raise(errors.first, [...errors.skip(1)]);
                }

                return Cont.empty();
              })
              .catchError((error2, errors2) {
                if (errors.isNotEmpty) {
                  return Cont.raise(errors.first, [...errors.skip(1), error2, ...errors2]);
                }

                return Cont.raise(error2, errors2);
              })
              .map(_absurd);
        } catch (error2, st2) {
          if (errors.isNotEmpty) {
            return Cont.raise(errors.first, [...errors.skip(1), ContError(error2, st2)]);
          } else {
            return Cont.raise(ContError(error2, st2));
          }
        }
      }

      try {
        final mainCont = use(ref);
        return mainCont
            .catchEmpty(() {
              return doProperRelease([]);
            })
            .catchError((error, errors) {
              return doProperRelease([error, ...errors]);
            })
            .flatMap((a) {
              return doProperRelease([]).catchEmpty(() {
                return Cont.of(a);
              });
            });
      } catch (error, st) {
        return doProperRelease([ContError(error, st)]);
      }
    });
  }
}

extension ContApplicativeExtension<A, A2> on Cont<A2 Function(A)> {
  Cont<A2> applySequentially(Cont<A> other) {
    return zipSequentially(other, (function, value) {
      return function(value);
    });
  }

  Cont<A2> applyConcurrently(Cont<A> other) {
    return zipConcurrently(other, (function, value) {
      return function(value);
    });
  }
}

extension ContFlattenExtension<A> on Cont<Cont<A>> {
  Cont<A> flatten() {
    return flatMap(_idfunc<Cont<A>>);
  }
}

extension FlatMapTrueFalseExtension on Cont<bool> {
  Cont<A2> ifThenElse<A2>(Cont<A2> thenCont, Cont<A2> elseCont) {
    return flatMap((condition) {
      if (condition) {
        return thenCont;
      } else {
        return elseCont;
      }
    });
  }

  Cont<A2> ifElseThen<A2>(Cont<A2> elseCont, Cont<A2> thenCont) {
    return ifThenElse(thenCont, elseCont);
  }
}

// little tooling

// Identity function
A _idfunc<A>(A a) {
  return a;
}

A _absurd<A>(Never never) {
  return never;
}

void _doNothing() {}

void _ignore1(dynamic a) {}

void _ignore2(dynamic a, dynamic b) {}

// a runner that runs an actions strictly once.
// if invoked more than once - does not do anything

final class _IdempotentRunner {
  bool _isDone = false;

  _IdempotentRunner();

  bool runIfNotDone(void Function() procedure) {
    if (_isDone) {
      return false;
    }
    _isDone = true;
    procedure();

    return true;
  }
}

final class Ref<S> {
  S _state;

  Ref._(S initial) : _state = initial;

  Cont<V> commit<V>(Cont<RefCommit<S, V> Function(S after)> Function(S before) f) {
    return Cont.fromRun((observer) {
      final before = _state;
      f(before).run(
        onFatal: observer.onFatal,
        onNone: observer.onNone,
        onFail: observer.onFail,
        onSome: (function) {
          final after = _state;
          final RefCommit<S, V> commit;
          try {
            commit = function(after);
          } catch (error, st) {
            observer.onFail(ContError(error, st), []);
            return;
          }
          commit.run(
            (errors) {
              if (errors.isEmpty) {
                observer.onNone();
                return;
              }

              observer.onFail(errors.first, errors.skip(1).toList());
            },
            (state, value) {
              _state = state;
              observer.onSome(value);
            },
          );
        },
      );
    });
  }
}
