final class Cont<A> {
  //

  final void Function(
    // observerErrorHandler MUST NOT FAIL EVER.
    void Function(ContError error, ContSignal signal) observerErrorHandler,
    void Function() none,
    void Function(ContError error, List<ContError> errors) fail,
    void Function(A value) some,
  )
  run;

  void execute({
    void Function(ContError error, ContSignal signal) observerErrorHandler = _ignore2,
    void Function() onNone = _doNothing,
    void Function(ContError, List<ContError> fail) onFail = _ignore2,
    void Function(A value) onSome = _ignore1,
  }) {
    run(observerErrorHandler, onNone, onFail, onSome);
  }

  // ! constructor must not be called by anything other than "Cont.fromRun" !
  const Cont._(this.run);

  // none and some should be called as a last instruction in "run" or saved to be called later
  static Cont<A> fromRun<A>(
    void Function(
      void Function(ContError error, ContSignal signal) observerErrorHandler,
      //
      bool Function() none,
      bool Function(ContError error, List<ContError> errors) fail,
      bool Function(A value) some,
    )
    run,
  ) {
    // guarantees idempotence
    // guarantees to catch throws
    return Cont._((observerErrorHandler, none, fail, some) {
      final runner = _IdempotentRunner();

      void handleUnrecoverableFailure(Object error, StackTrace st, ContSignal signal) {
        try {
          observerErrorHandler(ContError(error, st), signal);
        } catch (error, st) {
          // we schedule it in microtask to ensure that
          // there is no try-catch around it and it does fail
          // !best-effort crash unless a Zone catches it.!
          Future.microtask(() {
            Error.throwWithStackTrace(error, st);
          });
        }
      }

      bool guardedNone() {
        return runner.runIfNotDone(() {
          try {
            none();
          } catch (error, st) {
            handleUnrecoverableFailure(error, st, ContSignal.none);
          }
        });
      }

      bool guardedFail(ContError error, List<ContError> errors) {
        return runner.runIfNotDone(() {
          try {
            fail(error, errors);
          } catch (error, st) {
            handleUnrecoverableFailure(error, st, ContSignal.fail);
          }
        });
      }

      bool guardedSome(A a) {
        return runner.runIfNotDone(() {
          try {
            some(a);
          } catch (error, st) {
            handleUnrecoverableFailure(error, st, ContSignal.some);
          }
        });
      }

      try {
        run(
          (error, signal) {
            handleUnrecoverableFailure(error.error, error.st, signal);
          },
          guardedNone,
          guardedFail,
          guardedSome,
        );
      } catch (error, st) {
        guardedFail(ContError(error, st), []);
      }
    });
  }

  static Cont<A> fromDeferred<A>(Cont<A> Function() thunk) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      thunk().run(observerErrorHandler, none, fail, some);
    });
  }

  Cont<A2> flatMap<A2>(Cont<A2> Function(A value) f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(observerErrorHandler, none, fail, (a) {
        try {
          final contA2 = f(a);
          contA2.run(observerErrorHandler, none, fail, some);
        } catch (error, st) {
          fail(ContError(error, st), []);
        }
      });
    });
  }

  Cont<A> catchEmpty(Cont<A> Function() f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(
        observerErrorHandler,
        () {
          try {
            final contA = f();
            contA.run(observerErrorHandler, none, fail, some);
          } catch (error, st) {
            fail(ContError(error, st), []);
          }
        },
        fail,
        some,
      );
    });
  }

  Cont<A> catchError(Cont<A> Function(ContError error, List<ContError> errors) f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(observerErrorHandler, none, (error, errors) {
        try {
          final recoveryCont = f(error, errors);
          recoveryCont.run(observerErrorHandler, none, fail, some);
        } catch (error2, st) {
          fail(error, [...errors, ContError(error2, st)]);
        }
      }, some);
    });
  }

  Cont<A2> then<A2>(Cont<A2> cont) {
    return flatMap((_) {
      return cont;
    });
  }

  static Cont<A> fromThunk<A>(A Function() thunk) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      final a = thunk();
      some(a);
    });
  }

  static Cont<()> fromProcedure(void Function() procedure) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      procedure();
      some(());
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
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      none();
    });
  }

  static Cont<Never> zero() {
    return empty<Never>();
  }

  static Cont<A> raise<A>(ContError error, [List<ContError> errors = const []]) {
    final safeCopy = List<ContError>.from(errors);
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      fail(error, safeCopy);
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
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      final List<A> result = [];
      void add(int i) {
        if (i >= safeCopy.length) {
          some(result);
          return;
        }

        final cont = safeCopy[i];
        cont.run(observerErrorHandler, none, fail, (a) {
          result.add(a);
          add(i + 1);
        });
      }

      add(0);
    });
  }

  Cont<C> zipConcurrently<A2, C>(Cont<A2> other, C Function(A a, A2 a2) f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
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
            some(c);
          } catch (error, st) {
            fail(ContError(error, st), []);
            return;
          }
        } else {
          if (resultErrors.isEmpty) {
            none();
          } else {
            fail(resultErrors.first, resultErrors.skip(1).toList());
          }
        }
      }

      void handleNoneAndFail() {
        if (!isOneSome && !isOneFail) {
          isOneFail = true;
          return;
        }

        if (resultErrors.isEmpty) {
          none();
        } else {
          fail(resultErrors.first, resultErrors.skip(1).toList());
        }
      }

      run(
        observerErrorHandler,
        () {
          handleNoneAndFail();
        },
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
      );

      other.run(
        observerErrorHandler,
        () {
          handleNoneAndFail();
        },
        (error, errors) {
          // strict order must be followed
          resultErrors.add(error);
          resultErrors.addAll(errors);
          handleNoneAndFail();
        },
        (a2) {
          // strict order must be followed
          outerA2 = a2;
          handleSome();
        },
      );
    });
  }

  static Cont<List<A>> zipAllConcurrently<A>(List<Cont<A>> list) {
    final safeCopy = List<Cont<A>>.from(list);
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      if (safeCopy.isEmpty) {
        some(<A>[]);
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
          none();
          return;
        }

        fail(flattened.first, flattened.skip(1).toList());
      }

      for (final (i, cont) in safeCopy.indexed) {
        final index = i; // important
        cont.run(
          observerErrorHandler,
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
                  none();
                } else {
                  fail(flattened.first, flattened.skip(1).toList());
                }
              }
              return;
            }
            results[index] = a;
            if (amountOfFinishedContinuations >= safeCopy.length) {
              some(results.cast<A>());
            }
          },
        );
      }
    });
  }

  // always returns non-none and non-fail winner (first value)
  Cont<C> racePickWinner<A2, C>(Cont<A2> other, C Function(A a) lf, C Function(A2 a2) rf) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      final runner = _IdempotentRunner();

      bool isOneFailed = false;
      final List<ContError> resultErrors = [];

      void handleNoneOrFail(void Function() codeToUpdateState) {
        if (isOneFailed) {
          codeToUpdateState();

          if (resultErrors.isEmpty) {
            none();
            return;
          }

          fail(resultErrors.first, resultErrors.skip(1).toList());
          return;
        }
        isOneFailed = true;

        codeToUpdateState();
      }

      run(
        observerErrorHandler,
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
            final result = lf(a);
            runner.runIfNotDone(() {
              some(result);
            });
          } catch (error, st) {
            handleNoneOrFail(() {
              resultErrors.insert(0, ContError(error, st));
            });
          }
        },
      );

      other.run(
        observerErrorHandler,
        () {
          handleNoneOrFail(() {});
        },
        (error, errors) {
          handleNoneOrFail(() {
            resultErrors.add(error);
            resultErrors.addAll(errors);
          });
        },
        (a2) {
          try {
            final result = rf(a2);
            runner.runIfNotDone(() {
              some(result);
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
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      if (safeCopy.isEmpty) {
        none();
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
          none();
          return;
        }

        fail(flattened.first, flattened.skip(1).toList());
      }

      for (int i = 0; i < safeCopy.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = safeCopy[i];
        cont.run(
          observerErrorHandler,
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
            some((index, a));
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

  // always returns non-none and non-fail loser (last value)
  Cont<C> racePickLoser<A2, C>(Cont<A2> other, C Function(A a) lf, C Function(A2 a2) rf) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
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
          some(result as C);
          return;
        }

        codeToUpdateState();

        if (resultErrors.isEmpty) {
          none();
          return;
        }

        fail(resultErrors.first, resultErrors.skip(1).toList());
      }

      run(
        observerErrorHandler,
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
              final result = lf(a);
              some(result);
            } catch (error, st) {
              if (isResultAvailable) {
                some(result as C);
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
        observerErrorHandler,
        () {
          handleNoneOrFail(() {});
        },
        (error, errors) {
          handleNoneOrFail(() {
            resultErrors.add(error);
            resultErrors.addAll(errors);
          });
        },
        (a2) {
          if (isFirstComputed) {
            try {
              final result = rf(a2);
              some(result);
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
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      if (safeCopy.isEmpty) {
        none();
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
          some((lastValueIndex, lastValue as A));
          return;
        }

        final flattened = resultErrors.expand((list) {
          return list;
        }).toList();

        if (flattened.isEmpty) {
          none();
          return;
        }

        fail(flattened.first, flattened.skip(1).toList());
      }

      for (int i = 0; i < safeCopy.length; i++) {
        final index = i; // this is important to capture. if we reference "i" from onSome block, we might pick wrong index
        final cont = safeCopy[i];

        cont.run(
          observerErrorHandler,
          () {
            incrementFinishedAndCheckExit();
          },
          (error, errors) {
            resultErrors[index] = [error, ...errors];
            incrementFinishedAndCheckExit();
          },
          (a) {
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
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(
        observerErrorHandler,
        () {
          other.run(observerErrorHandler, none, fail, (a2) {
            try {
              final result = rf(a2);
              some(result);
            } catch (error, st) {
              fail(ContError(error, st), []);
            }
          });
        },
        (error, errors) {
          other.run(
            observerErrorHandler,
            () {
              fail(error, errors);
            },
            (error2, errors2) {
              fail(error, [...errors, error2, ...errors2]);
            },
            (a2) {
              try {
                final result = rf(a2);
                some(result);
              } catch (error, st) {
                fail(ContError(error, st), []);
              }
            },
          );
        },
        (a) {
          try {
            final result = lf(a);
            some(result);
          } catch (error, st) {
            fail(ContError(error, st), []);
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
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(
        observerErrorHandler,
        () {
          try {
            f();
          } catch (_) {
            // "f" is side effect. the user of "doOnNone" is responsible for making
            // sure that errors are caught and logged
            // the runtime crashes of "f" should not affect the main flow
          }
          none();
        },
        fail,
        some,
      );
    });
  }

  Cont<A> doOnFail(void Function(ContError error, List<ContError> errors) f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(observerErrorHandler, none, (error, errors) {
        try {
          f(error, errors);
        } catch (_) {
          // "f" is side effect. the user of "doOnFail" is responsible for making
          // sure that errors are caught and logged
          // the runtime crashes of "f" should not affect the main flow
        }
        fail(error, errors);
      }, some);
    });
  }

  Cont<A> doOnSome(void Function(A a) f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(observerErrorHandler, none, fail, (a) {
        try {
          f(a);
        } catch (_) {
          // "f" is side effect. the user of "doOnNone" is responsible for making
          // sure that errors are caught and logged
          // the runtime crashes of "f" should not affect the main flow
        }
        some(a);
      });
    });
  }

  Cont<A> doOnRun(void Function() f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      try {
        f();
      } catch (_) {
        // "f" is side effect. the user of "doOnNone" is responsible for making
        // sure that errors are caught and logged
        // the runtime crashes of "f" should not affect the main flow
      }
      run(observerErrorHandler, none, fail, some);
    });
  }

  Cont<A> runOn(Scheduler scheduler) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      scheduler.run(() {
        run(observerErrorHandler, none, fail, some);
      });
    });
  }

  Cont<A> noneOn(Scheduler scheduler) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(
        observerErrorHandler,
        () {
          scheduler.run(none);
        },
        fail,
        some,
      );
    });
  }

  Cont<A> failOn(Scheduler scheduler) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(observerErrorHandler, none, (error, errors) {
        scheduler.run(() {
          fail(error, errors);
        });
      }, some);
    });
  }

  Cont<A> someOn(Scheduler scheduler) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      run(observerErrorHandler, none, fail, (a) {
        scheduler.run(() {
          some(a);
        });
      });
    });
  }

  Cont<A> consumeOn(Scheduler scheduler) {
    return noneOn(scheduler).failOn(scheduler).someOn(scheduler);
  }

  Cont<A> scheduleOn(Scheduler scheduler) {
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

  bool isDone() {
    return _isDone;
  }

  bool runIfNotDone(void Function() procedure) {
    if (_isDone) {
      return false;
    }
    _isDone = true;
    procedure();

    return true;
  }

  bool runIfDone(void Function() procedure) {
    if (isDone()) {
      procedure();
      return false;
    }

    return true;
  }

  bool stop() {
    return runIfNotDone(() {});
  }
}

// Other API Types
final class Scheduler {
  final void Function() Function(void Function() action) schedule;

  const Scheduler._(this.schedule);

  void run(void Function() action) {
    schedule(action)();
  }

  static Scheduler custom(void Function() Function(void Function() action) schedule) {
    return Scheduler._(schedule);
  }

  static Scheduler delayed([Duration duration = Duration.zero]) {
    return Scheduler._((action) {
      return () {
        Future.delayed(duration, action);
      };
    });
  }

  static Scheduler microTask() {
    return Scheduler._((action) {
      return () {
        Future.microtask(action);
      };
    });
  }

  static Scheduler immediate() {
    return Scheduler._(_idfunc<void Function()>);
  }
}

final class RefCommit<S, V> {
  final (S, V)? _value;
  final List<ContError> _errors;

  const RefCommit._(this._value, this._errors);

  static RefCommit<S, V> skip<S, V>([List<ContError> errors = const []]) {
    return RefCommit._(null, errors);
  }

  static RefCommit<S, V> transit<S, V>(S state, V value) {
    return RefCommit._((state, value), []);
  }

  R match<R>(R Function(List<ContError>) ifSkip, R Function(S state, V value) ifTransit) {
    final value = _value;
    if (value == null) {
      return ifSkip(_errors);
    } else {
      return ifTransit(value.$1, value.$2);
    }
  }

  void run(void Function(List<ContError> errors) ifSkip, void Function(S state, V value) ifTransit) {
    match<void Function()>(
      (errors) {
        return () {
          ifSkip(errors);
        };
      },
      (state, value) {
        return () {
          ifTransit(state, value);
        };
      },
    )();
  }

  bool isSkip() {
    return match<bool>(
      (_) {
        return true;
      },
      (_, _) {
        return false;
      },
    );
  }

  bool isTransit() {
    return !isSkip();
  }
}

final class Ref<S> {
  S _state;

  Ref._(S initial) : _state = initial;

  Cont<V> commit<V>(Cont<RefCommit<S, V> Function(S after)> Function(S before) f) {
    return Cont.fromRun((observerErrorHandler, none, fail, some) {
      final before = _state;
      f(before).run(observerErrorHandler, none, fail, (function) {
        final after = _state;
        final RefCommit<S, V> commit;
        try {
          commit = function(after);
        } catch (error, st) {
          fail(ContError(error, st), []);
          return;
        }
        commit.run(
          (errors) {
            if (errors.isEmpty) {
              none();
              return;
            }

            fail(errors.first, errors.skip(1).toList());
          },
          (state, value) {
            _state = state;
            some(value);
          },
        );
      });
    });
  }
}

final class ContError {
  final Object error;
  final StackTrace st;

  const ContError(this.error, this.st);
}

enum ContSignal { none, fail, some }
