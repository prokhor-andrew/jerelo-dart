import 'package:jerelo/src/cont_observer.dart';
import 'package:jerelo/src/cont_reporter.dart';

final class Cont<A> {
  final void Function(ContReporter reporter, ContObserver<A> observer) run;

  // ! constructor must not be called by anything other than "Cont.fromRun" !
  const Cont._(this.run);

  // onNone and some should be called as a last instruction in "run" or saved to be called later
  static Cont<A> fromRun<A>(void Function(ContReporter reporter, ContObserver<A> observer) run) {
    // guarantees idempotence
    // guarantees to catch throws
    return Cont._((reporter, observer) {
      final runner = _IdempotentRunner();

      void handleUnrecoverableFailure(Object error, StackTrace st, _ContSignal signal) {
        try {
          final void Function() onFatal = switch (signal) {
            _ContSignal.none => () {
              reporter.onNone(error, st);
            },
            _ContSignal.fail => () {
              reporter.onFail(error, st);
            },
            _ContSignal.some => () {
              reporter.onSome(error, st);
            },
          };
          onFatal();
        } catch (error, st) {
          // we schedule it in microtask to ensure that
          // there is no try-catch around it and it does fail
          // !best-effort crash unless a Zone catches it.!
          Future.microtask(() {
            Error.throwWithStackTrace(error, st);
          });
        }
      }

      bool guardedFail(Object error, List<Object> errors) {
        return runner.runIfNotDone(() {
          try {
            observer.onFail(error, errors);
          } catch (error, st) {
            handleUnrecoverableFailure(error, st, _ContSignal.fail);
          }
        });
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
              runner.runIfNotDone(() {
                try {
                  observer.onNone();
                } catch (error, st) {
                  handleUnrecoverableFailure(error, st, _ContSignal.none);
                }
              });
            },
            guardedFail,
            (a) {
              runner.runIfNotDone(() {
                try {
                  observer.onSome(a);
                } catch (error, st) {
                  handleUnrecoverableFailure(error, st, _ContSignal.some);
                }
              });
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
            final recoveryCont = f(error, errors);
            recoveryCont.run(reporter, observer);
          } catch (error2) {
            observer.onFail(error, [...errors, error2]);
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
    final safeCopy = List<Object>.from(errors);
    return Cont.fromRun((reporter, observer) {
      observer.onFail(error, safeCopy);
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
        if (!isOneSome && !isOneFail) {
          isOneSome = true;
          return;
        }

        if (isOneSome) {
          try {
            final c = f(outerA as A, outerB as B);
            observer.onSome(c);
          } catch (error) {
            observer.onFail(error, []);
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
    final safeCopy = List<Cont<A>>.from(list);
    if (isSequential) {
      return Cont.fromRun((reporter, observer) {
        final List<A> result = [];
        void add(int i) {
          if (i >= safeCopy.length) {
            observer.onSome(result);
            return;
          }

          final cont = safeCopy[i];
          cont.run(
            reporter,
            observer.copyUpdateOnSome((a) {
              result.add(a);
              add(i + 1);
            }),
          );
        }

        add(0);
      });
    }

    return Cont.fromRun((reporter, observer) {
      if (safeCopy.isEmpty) {
        observer.onSome(<A>[]);
        return;
      }

      final results = List<A?>.filled(safeCopy.length, null);
      final resultErrors = List<List<Object>>.generate(safeCopy.length, (_) {
        return [];
      });

      bool isFailed = false;
      int amountOfFinishedContinuations = 0;

      void handleNoneOrFail(int index, List<Object> errors) {
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
          reporter,
          ContObserver(
            () {
              handleNoneOrFail(index, []);
            },
            (error, errors) {
              handleNoneOrFail(index, [error, ...errors]);
            },
            (a) {
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
          ),
        );
      }
    });
  }

  static Cont<A> race<A>(Cont<A> left, Cont<A> right, {bool pickWinner = true}) {
    if (pickWinner) {
      return Cont.fromRun((reporter, observer) {
        final runner = _IdempotentRunner();

        bool isOneFailed = false;
        final List<Object> resultErrors = [];

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

        left.run(
          reporter,
          ContObserver(
            () {
              handleNoneOrFail(() {});
            },
            (error, errors) {
              handleNoneOrFail(() {
                resultErrors.insert(0, error);
                resultErrors.insertAll(1, errors);
              });
            },
            (a) {
              try {
                runner.runIfNotDone(() {
                  observer.onSome(a);
                });
              } catch (error) {
                handleNoneOrFail(() {
                  resultErrors.insert(0, error);
                });
              }
            },
          ),
        );

        right.run(
          reporter,
          ContObserver(
            () {
              handleNoneOrFail(() {});
            },
            (error, errors) {
              handleNoneOrFail(() {
                resultErrors.add(error);
                resultErrors.addAll(errors);
              });
            },
            (a) {
              try {
                runner.runIfNotDone(() {
                  observer.onSome(a);
                });
              } catch (error) {
                handleNoneOrFail(() {
                  resultErrors.add(error);
                });
              }
            },
          ),
        );
      });
    }

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

      left.run(
        reporter,
        ContObserver(
          () {
            handleNoneOrFail(() {});
          },
          (error, errors) {
            handleNoneOrFail(() {
              resultErrors.insert(0, error);
              resultErrors.insertAll(1, errors);
            });
          },
          (a) {
            if (isFirstComputed) {
              try {
                observer.onSome(a);
              } catch (error) {
                if (isResultAvailable) {
                  observer.onSome(result as A);
                } else {
                  handleNoneOrFail(() {
                    resultErrors.insert(0, error);
                  });
                }
              }
              return;
            }

            try {
              result = a;
              isFirstComputed = true;
              isResultAvailable = true;
            } catch (error) {
              handleNoneOrFail(() {
                resultErrors.insert(0, error);
              });
            }
          },
        ),
      );

      right.run(
        reporter,
        ContObserver(
          () {
            handleNoneOrFail(() {});
          },
          (error, errors) {
            handleNoneOrFail(() {
              resultErrors.add(error);
              resultErrors.addAll(errors);
            });
          },
          (a) {
            if (isFirstComputed) {
              try {
                observer.onSome(a);
              } catch (error) {
                handleNoneOrFail(() {
                  resultErrors.add(error);
                });
              }
              return;
            }

            try {
              result = a;
              isFirstComputed = true;
              isResultAvailable = true;
            } catch (error) {
              handleNoneOrFail(() {
                resultErrors.add(error);
              });
            }
          },
        ),
      );
    });
  }

  Cont<A> raceWith(Cont<A> other, {bool pickWinner = true}) {
    return Cont.race(this, other, pickWinner: pickWinner);
  }

  static Cont<A> raceAll<A>(List<Cont<A>> list, {bool pickWinner = true}) {
    final safeCopy = List<Cont<A>>.from(list);
    if (pickWinner) {
      return Cont.fromRun((reporter, observer) {
        if (safeCopy.isEmpty) {
          observer.onNone();
          return;
        }

        final List<List<Object>> resultOfErrors = List.generate(safeCopy.length, (_) {
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
        }
      });
    }

    return Cont.fromRun((reporter, observer) {
      if (safeCopy.isEmpty) {
        observer.onNone();
        return;
      }

      final List<List<Object>> resultErrors = List.generate(safeCopy.length, (_) {
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

      for (int i = 0; i < safeCopy.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = safeCopy[i];

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
              lastValueIndex = index;

              incrementFinishedAndCheckExit();
            },
          ),
        );
      }
    });
  }

  static Cont<A> either<A>(Cont<A> left, Cont<A> right) {
    return Cont.fromRun((reporter, observer) {
      left.run(
        reporter,
        ContObserver(
          () {
            right.run(
              reporter,
              observer.copyUpdateOnSome((a2) {
                try {
                  observer.onSome(a2);
                } catch (error) {
                  observer.onFail(error, []);
                }
              }),
            );
          },
          (error, errors) {
            right.run(
              reporter,
              ContObserver(
                () {
                  observer.onFail(error, errors);
                },
                (error2, errors2) {
                  observer.onFail(error, [...errors, error2, ...errors2]);
                },
                (a2) {
                  try {
                    observer.onSome(a2);
                  } catch (error) {
                    observer.onFail(error, []);
                  }
                },
              ),
            );
          },
          (a) {
            try {
              observer.onSome(a);
            } catch (error) {
              observer.onFail(error, []);
            }
          },
        ),
      );
    });
  }

  Cont<A> or(Cont<A> other) {
    return Cont.either(this, other);
  }

  static Cont<A> any<A>(List<Cont<A>> list) {
    return list.fold<Cont<A>>(Cont.empty<A>(), Cont.either<A>);
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
    return flatMap(_idfunc<Cont<A>>);
  }
}

// private

// Identity function
A _idfunc<A>(A a) {
  return a;
}

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

enum _ContSignal { fail, none, some }
