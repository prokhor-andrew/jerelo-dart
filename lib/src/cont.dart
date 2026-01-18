import 'package:jerelo/src/cont_observer.dart';
import 'package:jerelo/src/cont_reporter.dart';

import 'cont_error.dart';

final class Cont<A> {
  final void Function({
    required ContReporter reporter,
    required ContObserver<A> observer,
    //
  })
  run;

  // ! constructor must not be called by anything other than "Cont.fromRun" !
  const Cont._(this.run);

  // onNone, onFail and onSome should be called as a last instruction in "run" or saved to be called later
  static Cont<A> fromRun<A>(void Function(ContReporter reporter, ContObserver<A> observer) run) {
    // guarantees idempotence
    // guarantees to catch throws
    return Cont._(({required reporter, required observer}) {
      bool isDone = false;

      void scheduleFatalError(ContError error) {
        // we schedule it in microtask to ensure that
        // there is no try-catch around it and it does fail
        // !best-effort crash unless a Zone catches it.!
        Future.microtask(() {
          Error.throwWithStackTrace(error.error, error.stackTrace);
        });
      }

      void handleUnrecoverableFailure(ContError error, _ContSignal signal) {
        try {
          final void Function() onFatal = switch (signal) {
            _ContSignal.terminate => () {
              reporter.onTerminate(error);
              scheduleFatalError(error);
            },
            _ContSignal.some => () {
              reporter.onSome(error);
              scheduleFatalError(error);
            },
          };
          onFatal();
        } catch (error, st) {
          scheduleFatalError(ContError(error, st));
        }
      }

      void guardedTerminate(List<ContError> errors) {
        if (isDone) {
          return;
        }
        isDone = true;
        try {
          observer.onTerminate(errors);
        } catch (error, st) {
          handleUnrecoverableFailure(ContError(error, st), _ContSignal.terminate);
        }
      }

      try {
        run(
          ContReporter(
            onTerminate: (error) {
              handleUnrecoverableFailure(error, _ContSignal.terminate);
            },
            onSome: (error) {
              handleUnrecoverableFailure(error, _ContSignal.some);
            },
          ),
          ContObserver(
            (errors) {
              guardedTerminate([...errors]); // making a defensive copy
            },
            (a) {
              if (isDone) {
                return;
              }
              isDone = true;
              try {
                observer.onSome(a);
              } catch (error, st) {
                handleUnrecoverableFailure(ContError(error, st), _ContSignal.some);
              }
            },
          ),
        );
      } catch (error, st) {
        guardedTerminate([ContError(error, st)]);
      }
    });
  }

  static Cont<A> fromDeferred<A>(Cont<A> Function() thunk) {
    return Cont.fromRun((reporter, observer) {
      thunk().run(reporter: reporter, observer: observer);
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
        reporter: reporter,
        observer: observer.copyUpdateOnSome((a) {
          try {
            final contA2 = f(a);
            contA2.run(reporter: reporter, observer: observer);
          } catch (error, st) {
            observer.onTerminate([ContError(error, st)]);
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

  Cont<A2> flatMapTo<A2>(Cont<A2> cont) {
    return flatMap0(() {
      return cont;
    });
  }

  Cont<A> flatTap<A2>(Cont<A2> Function(A value) f) {
    return flatMap((a) {
      return f(a).mapTo(a);
    });
  }

  Cont<A> flatTap0<A2>(Cont<A2> Function() f) {
    return flatTap((_) {
      return f();
    });
  }

  Cont<A> flatTapTo<A2>(Cont<A2> cont) {
    return flatTap0(() {
      return cont;
    });
  }

  Cont<A> catchTerminate(Cont<A> Function(List<ContError> errors) f) {
    return Cont.fromRun((reporter, observer) {
      run(
        reporter: reporter,
        observer: observer.copyUpdateOnTerminate((errors) {
          try {
            final contA = f(errors);
            contA.run(reporter: reporter, observer: observer);
          } catch (error, st) {
            observer.onTerminate([...errors, ContError(error, st)]);
          }
        }),
      );
    });
  }

  Cont<A> catchTerminate0(Cont<A> Function() f) {
    return catchTerminate((_) {
      return f();
    });
  }

  Cont<A> catchTerminateTo(Cont<A> cont) {
    return catchTerminate0(() {
      return cont;
    });
  }

  Cont<A> catchEmpty(Cont<A> Function() f) {
    return catchTerminate((errors) {
      if (errors.isNotEmpty) {
        return Cont.terminate(errors);
      }

      return f();
    });
  }

  Cont<A> catchEmptyTo(Cont<A> cont) {
    return catchEmpty(() {
      return cont;
    });
  }

  Cont<A> catchError(Cont<A> Function(ContError error, List<ContError> errors) f) {
    return catchTerminate((errors) {
      if (errors.isEmpty) {
        return Cont.terminate([]);
      }

      return f(errors.first, errors.skip(1).toList());
    });
  }

  Cont<A> catchError0(Cont<A> Function() f) {
    return catchError((_, _) {
      return f();
    });
  }

  Cont<A> catchErrorTo(Cont<A> cont) {
    return catchError0(() {
      return cont;
    });
  }

  // combinators)

  Cont<A> filter(bool Function(A value) f) {
    return flatMap((a) {
      if (!f(a)) {
        return Cont.empty<A>();
      }

      return Cont.of(a);
    });
  }

  // identities
  static Cont<A> of<A>(A value) {
    return Cont.fromRun((reporter, observer) {
      observer.onSome(value);
    });
  }

  static Cont<A> empty<A>() {
    return Cont.terminate([]);
  }

  static Cont<A> raise<A>(ContError error, [List<ContError> errors = const []]) {
    return Cont.terminate([error, ...errors]);
  }

  static Cont<A> terminate<A>(List<ContError> errors) {
    final safeCopyErrors0 = List<ContError>.from(errors);
    return Cont.fromRun((reporter, observer) {
      // this makes sure that if anybody outside mutates "errors"
      // we keep the same version as when function was called
      final safeCopyErrors = List<ContError>.from(safeCopyErrors0);
      observer.onTerminate(safeCopyErrors);
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
      final List<ContError> resultErrors = [];

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
        } catch (error, st) {
          observer.onTerminate([ContError(error, st)]);
        }
      }

      void handleTerminate() {
        if (isOneFail) {
          return;
        }
        isOneFail = true;
        observer.onTerminate(resultErrors);
      }

      try {
        left.run(
          reporter: reporter,
          observer: ContObserver(
            (errors) {
              // strict order must be followed
              resultErrors.insertAll(0, errors);
              handleTerminate();
            },
            (a) {
              // strict order must be followed
              outerA = a;
              handleSome();
            },
          ),
        );
      } catch (error, st) {
        // strict order must be followed
        resultErrors.insert(0, ContError(error, st));
        handleTerminate();
      }

      try {
        right.run(
          reporter: reporter,
          observer: ContObserver(
            (errors) {
              // strict order must be followed
              resultErrors.addAll(errors);
              handleTerminate();
            },
            (b) {
              // strict order must be followed
              outerB = b;
              handleSome();
            },
          ),
        );
      } catch (error, st) {
        // strict order must be followed
        resultErrors.add(ContError(error, st));
        handleTerminate();
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
        _stackSafeLoop<_Triple<(int, List<A>), List<ContError>, (ContError, _ContSignal)>, (int, List<A>), _Triple<List<A>, List<ContError>, (ContError, _ContSignal)>>(
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
                reporter: ContReporter(
                  onTerminate: (error) {
                    callback(_Value3((error, _ContSignal.terminate)));
                  },
                  onSome: (error) {
                    callback(_Value3((error, _ContSignal.some)));
                  },
                  //
                ),
                observer: ContObserver(
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
                observer.onSome(results);
                return;
              case _Value2(value: final errors):
                observer.onTerminate(errors);
                return;
              case _Value3(value: final value):
                final (error, signal) = value;
                switch (signal) {
                  case _ContSignal.terminate:
                    reporter.onTerminate(error);
                    return;
                  case _ContSignal.some:
                    reporter.onSome(error);
                    return;
                }
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

      void handleNoneOrFail(List<ContError> errors) {
        if (isDone) {
          return;
        }
        isDone = true;

        observer.onTerminate(errors);
      }

      for (final (i, cont) in safeCopy.indexed) {
        final index = i; // important
        try {
          cont.run(
            reporter: reporter,
            observer: ContObserver(
              (errors) {
                handleNoneOrFail([...errors]); // defensive copy
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
        } catch (error, st) {
          handleNoneOrFail([ContError(error, st)]);
        }
      }
    });
  }

  static Cont<A> _racePickWinner<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((reporter, observer) {
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
            observer.onSome(a);
          },
        );
      }

      try {
        left.run(
          reporter: reporter,
          observer: makeObserver((errors) {
            resultErrors.insertAll(0, errors);
          }),
        );
      } catch (error, st) {
        handleNoneOrFail(() {
          resultErrors.insert(0, ContError(error, st));
        });
      }

      try {
        right.run(
          reporter: reporter,
          observer: makeObserver((errors) {
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

  static Cont<A> _racePickLoser<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((reporter, observer) {
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
          observer.onSome(result as A);
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
          reporter: reporter,
          observer: makeObserver((errors) {
            resultErrors.insertAll(0, errors);
          }),
        );
      } catch (error, st) {
        handleNoneOrFail(() {
          resultErrors.insert(0, ContError(error, st));
        });
      }

      try {
        right.run(
          reporter: reporter,
          observer: makeObserver((errors) {
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
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = list[i];
        try {
          cont.run(
            reporter: reporter,
            observer: ContObserver(
              (errors) {
                handleTerminate(index, [...errors]); // defensive copy
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
        } catch (error, st) {
          handleTerminate(index, [ContError(error, st)]);
        }
      }
    });
  }

  static Cont<A> _raceAllPickLoser<A>(List<Cont<A>> list0) {
    return Cont.fromRun((reporter, observer) {
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
          observer.onSome(lastValue as A);
          return;
        }

        final flattened = resultErrors.expand((list) {
          return list;
        }).toList();

        observer.onTerminate(flattened);
      }

      for (int i = 0; i < list.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = list[i];

        try {
          cont.run(
            reporter: reporter,
            observer: ContObserver(
              (errors) {
                resultErrors[index] = [...errors];
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
          resultErrors[index] = [ContError(error, st)];
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
        reporter: reporter,
        observer: ContObserver(
          (errors) {
            try {
              right.run(
                reporter: reporter,
                observer: ContObserver(
                  (errors2) {
                    observer.onTerminate([...errors, ...errors2]);
                  },
                  (a2) {
                    observer.onSome(a2);
                  },
                ),
              );
            } catch (error, st) {
              observer.onTerminate([...errors, ContError(error, st)]);
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

      _stackSafeLoop<_Triple<(int, List<ContError>), A, (ContError, _ContSignal)>, (int, List<ContError>), _Triple<List<ContError>, A, (ContError, _ContSignal)>>(
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
              reporter: ContReporter(
                onTerminate: (error) {
                  callback(_Value3((error, _ContSignal.terminate)));
                },
                onSome: (error) {
                  callback(_Value3((error, _ContSignal.some)));
                },
                //
              ),
              observer: ContObserver(
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
              observer.onSome(a);
              return;
            case _Value3(value: final value):
              final (error, signal) = value;
              switch (signal) {
                case _ContSignal.terminate:
                  reporter.onTerminate(error);
                  return;
                case _ContSignal.some:
                  reporter.onSome(error);
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

enum _ContSignal { terminate, some }

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
