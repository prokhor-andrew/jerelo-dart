part of '../cont.dart';

Cont<E, F, List<A>> _allSequence<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy again
    _seq<ContError<F>, A>(
      total: list.length,
      onRun: (
        index,
        updateCancel,
        updatePrimary,
        updateSecondary,
      ) {
        Cont<E, F, A> cont = list[index];
        if (cont is Cont<E, F, Never>) {
          cont = cont.absurd<A>();
        }
        cont._run(
          runtime,
          ContObserver._(
            (error) {
              if (runtime.isCancelled()) {
                updateCancel();
                return;
              }
              updateSecondary(error);
            },
            (a) {
              if (runtime.isCancelled()) {
                updateCancel();
                return;
              }
              updatePrimary(a);
            },
          ),
        );
      },
      onPrimary: observer.onThen,
      onSecondary: observer.onElse,
      onError: (error) {
        observer.onElse(
          ThrownError.withStackTrace(
            error.error,
            error.stackTrace,
          ),
        );
      },
    );
  });
}

Cont<E, List<ContError<F>>, A> _anySequence<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy again
    _seq<A, ContError<F>>(
      total: list.length,
      onRun: (
        index,
        updateCancel,
        updatePrimary,
        updateSecondary,
      ) {
        Cont<E, F, A> cont = list[index];
        if (cont is Cont<E, F, Never>) {
          cont = cont.absurd<A>();
        }
        cont._run(
          runtime,
          ContObserver._(
            (error) {
              if (runtime.isCancelled()) {
                updateCancel();
                return;
              }
              updatePrimary(error);
            },
            (a) {
              if (runtime.isCancelled()) {
                updateCancel();
                return;
              }
              updateSecondary(a);
            },
          ),
        );
      },
      onPrimary: (error) {
        observer.onElse(ManualError(error));
      },
      onSecondary: observer.onThen,
      onError: (error) {
        observer.onElse(
          ThrownError.withStackTrace(
            error.error,
            error.stackTrace,
          ),
        );
      },
    );
  });
}

void _seq<F, A>({
  required int total,
  required void Function(
    int index,
    void Function() updateCancel,
    void Function(A) updatePrimary,
    void Function(F) updateSecondary,
  ) onRun,
  required void Function(List<A> values) onPrimary,
  required void Function(F f) onSecondary,
  required void Function(ThrownError error) onError,
}) {
  _stackSafeLoop<
      _Triple<List<A>, F, ThrownError>?, // state
      List<A>, // loop input
      _Triple<List<A>, F, ThrownError>? // loop output
      >(
    seed: _Value1([]),
    keepRunningIf: (state) {
      switch (state) {
        case null:
          return _StackSafeLoopPolicyStop(null);
        case _Value1(a: final values):
          if (values.length >= total) {
            return _StackSafeLoopPolicyStop(
              _Value1(values),
            );
          }
          return _StackSafeLoopPolicyKeepRunning(values);
        case _Value2(b: final f):
          return _StackSafeLoopPolicyStop(_Value2(f));
        case _Value3(c: final error):
          return _StackSafeLoopPolicyStop(_Value3(error));
      }
    },
    computation: (values, update) {
      final i = values.length;
      try {
        onRun(
          i,
          () {
            update(null);
          },
          (a) {
            update(
              _Value1([...values, a]),
            ); // defensive copy
          },
          (f) {
            update(_Value2(f));
          },
        );
      } catch (error, st) {
        update(
          _Value3(ThrownError.withStackTrace(error, st)),
        );
      }
    },
    escape: (triple) {
      switch (triple) {
        case null:
          // cancellation
          return;
        case _Value1(a: final values):
          onPrimary(values);
        case _Value2(b: final f):
          onSecondary(f);
        case _Value3(c: final error):
          onError(error);
      }
    },
  );
}

void _whenAllPar<P, S>({
  required int total,
  required void Function(
    int index,
    void Function(P) onPrimary,
    void Function(S) onSecondary,
  ) onRun,
  required S Function(S acc, S next) combine,
  required void Function(List<P> primaries) onAllPrimary,
  required void Function(S secondary) onAnySecondary,
}) {
  if (total == 0) {
    onAllPrimary([]);
    return;
  }

  S? seed;
  final List<P> results = [];
  var i = 0;

  void handlePrimary(P p) {
    i += 1;
    final seedCopy = seed;
    if (seedCopy != null && i >= total) {
      onAnySecondary(seedCopy);
      return;
    }
    results.add(p);
    if (i >= total) {
      onAllPrimary(results);
    }
  }

  void handleSecondary(S s) {
    i += 1;
    final seedCopy = seed;
    if (seedCopy == null) {
      if (i >= total) {
        onAnySecondary(s);
        return;
      }
      seed = s;
    } else {
      final newSeed = combine(seedCopy, s);
      if (i >= total) {
        onAnySecondary(newSeed);
        return;
      }
      seed = newSeed;
    }
  }

  for (var index = 0; index < total; index++) {
    onRun(index, handlePrimary, handleSecondary);
  }
}

Cont<E, F, List<A>> _whenAllAll<E, F, A>(
  List<Cont<E, F, A>> list,
  ContError<F> Function(
    ContError<F> acc,
    ContError<F> error,
  ) combine,
) {
  list = list.toList();
  return Cont.fromRun((runtime, observer) {
    list = list.toList();
    _whenAllPar<A, ContError<F>>(
      total: list.length,
      onRun: (index, onPrimary, onSecondary) {
        final cont = list[index];
        try {
          cont._run(
            runtime,
            ContObserver._(
              (error) {
                if (runtime.isCancelled()) {
                  return;
                }
                onSecondary(error);
              },
              (a) {
                if (runtime.isCancelled()) {
                  return;
                }
                onPrimary(a);
              },
            ),
          );
        } catch (panic, st) {
          onSecondary(
            ThrownError.withStackTrace(panic, st),
          );
        }
      },
      combine: combine,
      onAllPrimary: observer.onThen,
      onAnySecondary: observer.onElse,
    );
  });
}

Cont<E, List<ContError<F>>, A> _whenAllAny<E, F, A>(
  List<Cont<E, F, A>> list,
  A Function(A acc, A value) combine,
) {
  list = list.toList();
  return Cont.fromRun((runtime, observer) {
    list = list.toList();
    _whenAllPar<ContError<F>, A>(
      total: list.length,
      onRun: (index, onPrimary, onSecondary) {
        final cont = list[index];
        try {
          cont._run(
            runtime,
            ContObserver._(
              (error) {
                if (runtime.isCancelled()) {
                  return;
                }
                onPrimary(error);
              },
              (a) {
                if (runtime.isCancelled()) {
                  return;
                }
                onSecondary(a);
              },
            ),
          );
        } catch (panic, st) {
          onPrimary(ThrownError.withStackTrace(panic, st));
        }
      },
      combine: combine,
      onAllPrimary: (errors) {
        return observer.onElse(
          ManualError(errors),
        );
      },
      onAnySecondary: observer.onThen,
    );
  });
}

void _quitFastPar<E, QF, C>({
  required ContRuntime<E> runtime,
  required int total,
  required void Function(
    int index,
    ContRuntime<E> sharedRuntime,
    void Function(QF) onQuitFast,
    void Function(C) onCollect,
  ) onRun,
  required void Function(QF value) onFirstQuitFast,
  required void Function(List<C> collected) onAllCollected,
}) {
  if (total == 0) {
    onAllCollected([]);
    return;
  }

  bool isDone = false;
  final collectedResults = List<C?>.filled(total, null);
  int amountOfCollected = 0;

  final ContRuntime<E> sharedRuntime = ContRuntime._(
    runtime.env(),
    () {
      return runtime.isCancelled() || isDone;
    },
    runtime.onPanic,
  );

  void handleQuitFast(QF value) {
    if (isDone) {
      return;
    }
    isDone = true;
    onFirstQuitFast(value);
  }

  for (int i = 0; i < total; i++) {
    onRun(
      i,
      sharedRuntime,
      (qf) {
        if (sharedRuntime.isCancelled()) {
          return;
        }
        handleQuitFast(qf);
      },
      (c) {
        if (sharedRuntime.isCancelled()) {
          return;
        }

        collectedResults[i] = c;
        amountOfCollected += 1;
        if (amountOfCollected < total) {
          return;
        }
        onAllCollected(collectedResults.cast<C>());
      },
    );
  }
}

Cont<E, F, List<A>> _quitFastAll<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((runtime, observer) {
    list = list.toList();
    _quitFastPar<E, ContError<F>, A>(
      runtime: runtime,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect) {
        try {
          list[i]._run(
            shared,
            ContObserver._(
              onQuitFast,
              onCollect,
            ),
          );
        } catch (error, st) {
          onQuitFast(ThrownError.withStackTrace(error, st));
        }
      },
      onFirstQuitFast: observer.onElse,
      onAllCollected: observer.onThen,
    );
  });
}

Cont<E, List<ContError<F>>, A> _quitFastAny<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((runtime, observer) {
    list = list.toList();
    _quitFastPar<E, A, ContError<F>>(
      runtime: runtime,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect) {
        try {
          list[i]._run(
            shared,
            ContObserver._(
              onCollect,
              onQuitFast,
            ),
          );
        } catch (error, st) {
          onCollect(ThrownError.withStackTrace(error, st));
        }
      },
      onFirstQuitFast: observer.onThen,
      onAllCollected: (errors) {
        observer.onElse(ManualError(errors));
      },
    );
  });
}