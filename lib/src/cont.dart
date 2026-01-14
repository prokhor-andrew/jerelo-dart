import 'package:jerelo/src/cont_observer.dart';
import 'package:jerelo/src/cont_reporter.dart';

final class Cont<A> {
  final void Function(ContReporter reporter, ContObserver<A> observer) run;

  // ! constructor must not be called by anything other than "Cont.fromRun" !
  const Cont._(this.run);

  // onNone, onFail and onSome should be called as a last instruction in "run" or saved to be called later
  static Cont<A> fromRun<A>(void Function(ContReporter reporter, ContObserver<A> observer) run) {
    // guarantees idempotence
    // guarantees to catch throws
    return Cont._((reporter, observer) {
      bool isDone = false;

      void scheduleFatalError(Object error, StackTrace st) {
        // we schedule it in microtask to ensure that
        // there is no try-catch around it and it does fail
        // !best-effort crash unless a Zone catches it.!
        Future.microtask(() {
          Error.throwWithStackTrace(error, st);
        });
      }

      void handleUnrecoverableFailure(Object error, StackTrace st, _ContSignal signal) {
        try {
          final void Function() onFatal = switch (signal) {
            _ContSignal.none => () {
              reporter.onNone(error, st);
              scheduleFatalError(error, st);
            },
            _ContSignal.fail => () {
              reporter.onFail(error, st);
              scheduleFatalError(error, st);
            },
            _ContSignal.some => () {
              reporter.onSome(error, st);
              scheduleFatalError(error, st);
            },
          };
          onFatal();
        } catch (error, st) {
          scheduleFatalError(error, st);
        }
      }

      void guardedFail(Object error, List<Object> errors) {
        if (isDone) {
          return;
        }
        isDone = true;
        try {
          observer.onFail(error, errors);
        } catch (error, st) {
          handleUnrecoverableFailure(error, st, _ContSignal.fail);
        }
        return;
      }

      try {
        run(
          ContReporter(
            onNone: (error, st) {
              handleUnrecoverableFailure(error, st, _ContSignal.none);
            },
            onFail: (error, st) {
              handleUnrecoverableFailure(error, st, _ContSignal.fail);
            },
            onSome: (error, st) {
              handleUnrecoverableFailure(error, st, _ContSignal.some);
            },
          ),
          ContObserver(
            () {
              if (isDone) {
                return;
              }
              isDone = true;
              try {
                observer.onNone();
              } catch (error, st) {
                handleUnrecoverableFailure(error, st, _ContSignal.none);
              }
            },
            (error, errors) {
              guardedFail(error, [...errors]); // making a defensive copy
            },
            (a) {
              if (isDone) {
                return;
              }
              isDone = true;
              try {
                observer.onSome(a);
              } catch (error, st) {
                handleUnrecoverableFailure(error, st, _ContSignal.some);
              }
            },
          ),
        );
      } catch (error) {
        guardedFail(error, []);
      }
    });
  }

  static Cont<A> fromDeferred<A>(Cont<A> Function() thunk) {
    return Cont.fromRun((reporter, observer) {
      thunk().run(reporter, observer);
    });
  }

  // maps
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

  Cont<A2> mapTo<A2>(A2 value) {
    return map0(() {
      return value;
    });
  }

  // monadic-like
  Cont<A2> flatMap<A2>(Cont<A2> Function(A value) f) {
    return Cont.fromRun((reporter, observer) {
      run(
        reporter,
        observer.copyUpdateOnSome((a) {
          try {
            final contA2 = f(a);
            contA2.run(reporter, observer);
          } catch (error) {
            observer.onFail(error, []);
          }
        }),
      );
    });
  }

  Cont<A2> flatMap0<A2>(Cont<A2> Function() f) {
    return flatMap((_) {
      return f();
    });
  }

  Cont<A> catchEmpty(Cont<A> Function() f) {
    return Cont.fromRun((reporter, observer) {
      run(
        reporter,
        observer.copyUpdateOnNone(() {
          try {
            final contA = f();
            contA.run(reporter, observer);
          } catch (error) {
            observer.onFail(error, []);
          }
        }),
      );
    });
  }

  Cont<A> catchError(Cont<A> Function(Object error, List<Object> errors) f) {
    return Cont.fromRun((reporter, observer) {
      run(
        reporter,
        observer.copyUpdateOnFail((error, errors) {
          try {
            final recoveryCont = f(error, [...errors]); // safe copy of errors
            recoveryCont.run(reporter, observer);
          } catch (error2) {
            observer.onFail(error, [...errors, error2]); // safe copy of errors
          }
        }),
      );
    });
  }

  Cont<A> catchError0(Cont<A> Function() f) {
    return catchError((_, _) {
      return f();
    });
  }

  // identities
  static Cont<A> of<A>(A value) {
    return Cont.fromRun((reporter, observer) {
      observer.onSome(value);
    });
  }

  static Cont<A> empty<A>() {
    return Cont.fromRun((reporter, observer) {
      observer.onNone();
    });
  }

  static Cont<A> raise<A>(Object error, [List<Object> errors = const []]) {
    // this makes sure that if anybody outside mutates "errors"
    // we keep the same version as when function was called
    final safeCopyErrors0 = List<Object>.from(errors);
    return Cont.fromRun((reporter, observer) {
      // this copy makes sure that if 1 object of continuation is used to run multiple times
      // and one of them mutates it, we still keep original version for both
      final safeCopyErrors = List<Object>.from(safeCopyErrors0);
      observer.onFail(error, safeCopyErrors);
    });
  }

  // lax-monoidal

  static Cont<C> both<A, B, C>(
    Cont<A> left,
    Cont<B> right,
    C Function(A a, B b) f, {
    bool isSequential = true,
    //
  }) {
    if (isSequential) {
      return left.flatMap((a) {
        return right.map((a2) {
          return f(a, a2);
        });
      });
    }

    return Cont.fromRun((reporter, observer) {
      bool isOneFail = false;
      bool isOneSome = false;

      A? outerA;
      B? outerB;
      final List<Object> resultErrors = [];

      void handleSome() {
        if (isOneFail) {
          return;
        }

        if (!isOneSome) {
          isOneSome = true;
          return;
        }

        try {
          final c = f(outerA as A, outerB as B);
          observer.onSome(c);
        } catch (error) {
          observer.onFail(error, []);
        }
      }

      void handleNoneAndFail() {
        if (isOneFail) {
          return;
        }
        isOneFail = true;
        if (resultErrors.isEmpty) {
          observer.onNone();
        } else {
          observer.onFail(resultErrors.first, resultErrors.skip(1).toList());
        }
      }

      try {
        left.run(
          reporter,
          ContObserver(
            handleNoneAndFail,
            (error, errors) {
              // strict order must be followed
              resultErrors.insert(0, error);
              resultErrors.insertAll(1, errors);
              handleNoneAndFail();
            },
            (a) {
              // strict order must be followed
              outerA = a;
              handleSome();
            },
          ),
        );
      } catch (error) {
        // strict order must be followed
        resultErrors.insert(0, error);
        handleNoneAndFail();
      }

      try {
        right.run(
          reporter,
          ContObserver(
            handleNoneAndFail,
            (error, errors) {
              // strict order must be followed
              resultErrors.add(error);
              resultErrors.addAll(errors);
              handleNoneAndFail();
            },
            (b) {
              // strict order must be followed
              outerB = b;
              handleSome();
            },
          ),
        );
      } catch (error) {
        // strict order must be followed
        resultErrors.add(error);
        handleNoneAndFail();
      }
    });
  }

  Cont<C> and<B, C>(
    Cont<B> other,
    C Function(A a, B b) f, {
    bool isSequential = true,
    //
  }) {
    return Cont.both(this, other, f, isSequential: isSequential);
  }

  static Cont<List<A>> all<A>(
    List<Cont<A>> list, {
    bool isSequential = true,
    //
  }) {
    final safeCopy0 = List<Cont<A>>.from(list);
    if (isSequential) {
      return Cont.fromRun((reporter, observer) {
        final safeCopy = List<Cont<A>>.from(safeCopy0);
        _stackSafeLoop<_Triple<(int, List<A>), List<Object>, (Object, StackTrace, _ContSignal)>, (int, List<A>), _Triple<List<A>, List<Object>, (Object, StackTrace, _ContSignal)>>(
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
              case _Value3(value: final value):
                return _StackSafeLoopPolicyStop(_Value3(value));
            }
          },
          computation: (tuple, callback) {
            final (i, values) = tuple;
            final cont = safeCopy[i];
            try {
              cont.run(
                ContReporter(
                  onNone: (error, st) {
                    callback(_Value3((error, st, _ContSignal.none)));
                  },
                  onFail: (error, st) {
                    callback(_Value3((error, st, _ContSignal.fail)));
                  },
                  onSome: (error, st) {
                    callback(_Value3((error, st, _ContSignal.some)));
                  },
                  //
                ),
                ContObserver(
                  () {
                    callback(_Value2([]));
                  },
                  (error, errors) {
                    callback(_Value2([error, ...errors]));
                  },
                  (a) {
                    callback(_Value1((i + 1, [...values, a])));
                  },
                  //
                ),
              );
            } catch (error) {
              callback(_Value2([error]));
            }
          },
          escape: (triple) {
            switch (triple) {
              case _Value1(value: final results):
                observer.onSome(results);
                break;
              case _Value2(value: final errors):
                if (errors.isEmpty) {
                  observer.onNone();
                  return;
                }
                observer.onFail(errors.first, errors.skip(1).toList());
                break;
              case _Value3(value: final value):
                final (error, st, signal) = value;
                switch (signal) {
                  case _ContSignal.fail:
                    reporter.onFail(error, st);
                    break;
                  case _ContSignal.none:
                    reporter.onNone(error, st);
                    break;
                  case _ContSignal.some:
                    reporter.onSome(error, st);
                    break;
                }
                break;
            }
          },
          //
        );
      });
    }

    return Cont.fromRun((reporter, observer) {
      final safeCopy = List<Cont<A>>.from(safeCopy0);

      if (safeCopy.isEmpty) {
        observer.onSome(<A>[]);
        return;
      }

      bool isDone = false;
      final results = List<A?>.filled(safeCopy.length, null);

      int amountOfFinishedContinuations = 0;

      void handleNoneOrFail(List<Object> errors) {
        if (isDone) {
          return;
        }
        isDone = true;

        if (errors.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(errors.first, errors.skip(1).toList());
      }

      for (final (i, cont) in safeCopy.indexed) {
        final index = i; // important
        try {
          cont.run(
            reporter,
            ContObserver(
              () {
                handleNoneOrFail([]);
              },
              (error, errors) {
                handleNoneOrFail([error, ...errors]);
              },
              (a) {
                if (isDone) {
                  return;
                }

                results[index] = a;
                amountOfFinishedContinuations += 1;

                if (amountOfFinishedContinuations < safeCopy.length) {
                  return;
                }

                observer.onSome(results.cast<A>());
              },
            ),
          );
        } catch (error) {
          handleNoneOrFail([error]);
        }
      }
    });
  }

  static Cont<A> _racePickWinner<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((reporter, observer) {
      bool isOneFailed = false;
      final List<Object> resultErrors = [];
      bool isDone = false;

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

      ContObserver<A> makeObserver(void Function(Object object, List<Object> errors) codeToUpdateState) {
        return ContObserver(
          () {
            if (isDone) {
              return;
            }
            handleNoneOrFail(() {});
          },
          (error, errors) {
            if (isDone) {
              return;
            }
            handleNoneOrFail(() {
              codeToUpdateState(error, errors);
            });
          },
          (a) {
            if (isDone) {
              return;
            }
            isDone = true;
            observer.onSome(a);
          },
        );
      }

      try {
        left.run(
          reporter,
          makeObserver((error, errors) {
            resultErrors.insert(0, error);
            resultErrors.insertAll(1, errors);
          }),
        );
      } catch (error) {
        handleNoneOrFail(() {
          resultErrors.insert(0, error);
        });
      }

      try {
        right.run(
          reporter,
          makeObserver((error, errors) {
            resultErrors.add(error);
            resultErrors.addAll(errors);
          }),
        );
      } catch (error) {
        handleNoneOrFail(() {
          resultErrors.add(error);
        });
      }
    });
  }

  static Cont<A> _racePickLoser<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((reporter, observer) {
      bool isFirstComputed = false;

      final List<Object> resultErrors = [];

      bool isResultAvailable = false;
      A? result;

      void handleNoneOrFail(void Function() codeToUpdateState) {
        if (!isFirstComputed) {
          isFirstComputed = true;
          codeToUpdateState();
          return;
        }

        if (isResultAvailable) {
          observer.onSome(result as A);
          return;
        }

        codeToUpdateState();

        if (resultErrors.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(resultErrors.first, resultErrors.skip(1).toList());
      }

      ContObserver<A> makeObserver(void Function(Object object, List<Object> errors) codeToUpdateState) {
        return ContObserver(
          () {
            handleNoneOrFail(() {});
          },
          (error, errors) {
            handleNoneOrFail(() {
              codeToUpdateState(error, errors);
            });
          },
          (a) {
            if (isFirstComputed) {
              observer.onSome(a);
              return;
            }
            result = a;
            isFirstComputed = true;
            isResultAvailable = true;
          },
        );
      }

      try {
        left.run(
          reporter,
          makeObserver((error, errors) {
            resultErrors.insert(0, error);
            resultErrors.insertAll(1, errors);
          }),
        );
      } catch (error) {
        handleNoneOrFail(() {
          resultErrors.insert(0, error);
        });
      }

      try {
        right.run(
          reporter,
          makeObserver((error, errors) {
            resultErrors.add(error);
            resultErrors.addAll(errors);
          }),
        );
      } catch (error) {
        handleNoneOrFail(() {
          resultErrors.add(error);
        });
      }
    });
  }

  static Cont<A> race<A>(Cont<A> left, Cont<A> right, {bool pickWinner = true}) {
    if (pickWinner) {
      return _racePickWinner<A>(left, right);
    }

    return _racePickLoser(left, right);
  }

  Cont<A> raceWith(Cont<A> other, {bool pickWinner = true}) {
    return Cont.race(this, other, pickWinner: pickWinner);
  }

  static Cont<A> _raceAllPickWinner<A>(List<Cont<A>> list0) {
    return Cont.fromRun((reporter, observer) {
      final list = List<Cont<A>>.from(list0);
      if (list.isEmpty) {
        observer.onNone();
        return;
      }

      final List<List<Object>> resultOfErrors = List.generate(list.length, (_) {
        return [];
      });

      bool isWinnerFound = false;
      int numberOfFinished = 0;

      void handleNoneAndFail(int index, List<Object> errors) {
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

        if (flattened.isEmpty) {
          observer.onNone();
          return;
        }

        observer.onFail(flattened.first, flattened.skip(1).toList());
      }

      for (int i = 0; i < list.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = list[i];
        try {
          cont.run(
            reporter,
            ContObserver(
              () {
                handleNoneAndFail(index, []);
              },
              (error, errors) {
                handleNoneAndFail(index, [error, ...errors]);
              },
              (a) {
                if (isWinnerFound) {
                  return;
                }
                isWinnerFound = true;
                observer.onSome(a);
              },
            ),
          );
        } catch (error) {
          handleNoneAndFail(index, [error]);
        }
      }
    });
  }

  static Cont<A> _raceAllPickLoser<A>(List<Cont<A>> list0) {
    return Cont.fromRun((reporter, observer) {
      final list = List<Cont<A>>.from(list0);
      if (list.isEmpty) {
        observer.onNone();
        return;
      }

      final List<List<Object>> resultErrors = List.generate(list.length, (_) {
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
          observer.onSome(lastValue as A);
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

      for (int i = 0; i < list.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = list[i];

        try {
          cont.run(
            reporter,
            ContObserver(
              incrementFinishedAndCheckExit,
              (error, errors) {
                resultErrors[index] = [error, ...errors];
                incrementFinishedAndCheckExit();
              },
              (a) {
                lastValue = a;
                isItemFoundAvailable = true;

                incrementFinishedAndCheckExit();
              },
            ),
          );
        } catch (error) {
          resultErrors[index] = [error];
          incrementFinishedAndCheckExit();
        }
      }
    });
  }

  static Cont<A> raceAll<A>(List<Cont<A>> list, {bool pickWinner = true}) {
    final safeCopy = List<Cont<A>>.from(list);
    if (pickWinner) {
      return _raceAllPickWinner(safeCopy);
    }

    return _raceAllPickLoser(safeCopy);
  }

  // this one should be oky.
  static Cont<A> either<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((reporter, observer) {
      left.run(
        reporter,
        ContObserver(
          () {
            try {
              right.run(
                reporter,
                observer.copyUpdateOnSome((a2) {
                  observer.onSome(a2);
                }),
              );
            } catch (error) {
              observer.onFail(error);
            }
          },
          (error, errors) {
            try {
              right.run(
                reporter,
                ContObserver(
                  () {
                    observer.onFail(error, [...errors]);
                  },
                  (error2, errors2) {
                    observer.onFail(error, [...errors, error2, ...errors2]);
                  },
                  (a2) {
                    observer.onSome(a2);
                  },
                ),
              );
            } catch (error2) {
              observer.onFail(error, [...errors, error2]);
            }
          },
          (a) {
            observer.onSome(a);
          },
        ),
      );
    });
  }

  Cont<A> or(Cont<A> other) {
    return Cont.either(this, other);
  }

  static Cont<A> any<A>(List<Cont<A>> list) {
    final List<Cont<A>> safeCopy0 = List<Cont<A>>.from(list);

    return Cont.fromRun((reporter, observer) {
      final safeCopy = List<Cont<A>>.from(safeCopy0);

      _stackSafeLoop<_Triple<(int, List<Object>), A, (Object, StackTrace, _ContSignal)>, (int, List<Object>), _Triple<List<Object>, A, (Object, StackTrace, _ContSignal)>>(
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
            case _Value3(value: final triple):
              return _StackSafeLoopPolicyStop(_Value3(triple));
          }
        },
        computation: (tuple, callback) {
          final (index, errors) = tuple;
          final cont = safeCopy[index];

          try {
            cont.run(
              ContReporter(
                onNone: (error, st) {
                  callback(_Value3((error, st, _ContSignal.none)));
                },
                onFail: (error, st) {
                  callback(_Value3((error, st, _ContSignal.fail)));
                },
                onSome: (error, st) {
                  callback(_Value3((error, st, _ContSignal.some)));
                },
                //
              ),
              ContObserver(
                () {
                  callback(_Value1((index + 1, errors)));
                },
                (error, errors2) {
                  callback(_Value1((index + 1, [...errors, error, ...errors2])));
                },
                (a) {
                  callback(_Value2(a));
                },
                //
              ),
            );
          } catch (error) {
            callback(_Value1((index + 1, [...errors, error])));
          }
        },
        escape: (triple) {
          switch (triple) {
            case _Value1(value: final errors):
              if (errors.isEmpty) {
                observer.onNone();
                return;
              }
              observer.onFail(errors.first, errors.skip(1).toList());
              return;
            case _Value2(value: final a):
              observer.onSome(a);
              return;
            case _Value3(value: final value):
              final (error, st, signal) = value;
              switch (signal) {
                case _ContSignal.fail:
                  reporter.onFail(error, st);
                  return;
                case _ContSignal.none:
                  reporter.onNone(error, st);
                  return;
                case _ContSignal.some:
                  reporter.onSome(error, st);
                  return;
              }
          }
        },
        //
      );
    });
  }
}

// applicatives
extension ContApplicativeExtension<A, A2> on Cont<A2 Function(A)> {
  Cont<A2> apply(Cont<A> other, {bool isSequential = true}) {
    return and(other, (function, value) {
      return function(value);
    }, isSequential: isSequential);
  }
}

extension ContFlattenExtension<A> on Cont<Cont<A>> {
  Cont<A> flatten() {
    return flatMap((contA) => contA);
  }
}

enum _ContSignal { fail, none, some }

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

sealed class _Triple<A, B, C> {
  const _Triple();
}

final class _Value1<A, B, C> extends _Triple<A, B, C> {
  final A value;

  const _Value1(this.value);
}

final class _Value2<A, B, C> extends _Triple<A, B, C> {
  final B value;

  const _Value2(this.value);
}

final class _Value3<A, B, C> extends _Triple<A, B, C> {
  final C value;

  const _Value3(this.value);
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
