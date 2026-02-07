part of '../cont.dart';

/// Sequential execution of all continuations in the list.
///
/// Runs continuations one by one in order, stops at first failure.
Cont<E, List<A>> _allSequence<E, A>(List<Cont<E, A>> list) {
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy
    _stackSafeLoop<
      _Either<(int, List<A>), List<ContError>?>,
      (int, List<A>),
      _Either<(), _Either<List<A>, List<ContError>>>
    >(
      seed: _Left((0, [])),
      keepRunningIf: (state) {
        switch (state) {
          case _Left(value: final value):
            final (index, results) = value;
            if (index >= list.length) {
              return _StackSafeLoopPolicyStop(
                _Right(_Left(results)),
              );
            }
            return _StackSafeLoopPolicyKeepRunning((
              index,
              results,
            ));
          case _Right(value: final value):
            if (value != null) {
              return _StackSafeLoopPolicyStop(
                _Right(_Right(value)),
              );
            } else {
              return _StackSafeLoopPolicyStop(
                _Left(()),
              );
            }
        }
      },
      computation: (tuple, callback) {
        final (i, values) = tuple;
        Cont<E, A> cont = list[i];
        if (cont is Cont<E, Never>) {
          cont = cont.absurd<A>();
        }
        try {
          cont._run(
            runtime,
            ContObserver._(
              (errors) {
                if (runtime.isCancelled()) {
                  callback(_Right(null));
                  return;
                }
                callback(_Right([...errors]));
              },
              (a) {
                if (runtime.isCancelled()) {
                  callback(_Right(null));
                  return;
                }

                callback(
                  _Left((i + 1, [...values, a])),
                );
              },
              //
            ),
          );
        } catch (error, st) {
          callback(_Right([ContError(error, st)]));
        }
      },
      escape: (either) {
        switch (either) {
          case _Left():
            // cancellation
            return;
          case _Right(value: final either):
            switch (either) {
              case _Left(value: final results):
                observer.onValue(results);
                return;
              case _Right(value: final errors):
                observer.onTerminate(errors);
                return;
            }
        }
      },
      //
    );
  });
}

/// Parallel execution with error merging.
///
/// Runs all in parallel, waits for all to complete,
/// and merges errors if any fail.
Cont<E, List<A>> _allMergeWhenAll<E, A>(List<Cont<E, A>> list) {
  return Cont.fromRun((runtime, observer) {
    list = list.toList();

    if (list.isEmpty) {
      observer.onValue(<A>[]);
      return;
    }

    if (list.length == 1) {
      final cont = list[0];
      try {
        cont._run(
          runtime,
          ContObserver._(
            (errors) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onTerminate([...errors]);
            },
            (a) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onValue([a]);
            },
          ),
        );
      } catch (error, st) {
        observer.onTerminate([ContError(error, st)]);
      }
      return;
    }

    List<ContError>? seed;

    final List<A> results = [];

    var i = 0;
    for (final cont in list) {
      try {
        cont._run(
          runtime,
          ContObserver._(
            (errors) {
              if (runtime.isCancelled()) {
                return;
              }

              i += 1;
              final seedRefCopy = seed;
              if (seedRefCopy == null) {
                seed = [...errors];
              } else {
                final safeCopyOfResultErrors =
                    seedRefCopy + errors;

                seed = safeCopyOfResultErrors;
              }

              if (i >= list.length) {
                observer.onTerminate(seed!);
                return;
              }
            },
            (a) {
              if (runtime.isCancelled()) {
                return;
              }

              i += 1;
              final seedCopy = seed;
              if (seedCopy != null) {
                if (i >= list.length) {
                  observer.onTerminate(seedCopy);
                }
                return;
              }

              results.add(a);
              if (i >= list.length) {
                observer.onValue(results);
              }
            },
          ),
          //
        );
      } catch (error, st) {
        i += 1;
        final seedCopy = seed;
        if (seedCopy == null) {
          seed = [ContError(error, st)];
        } else {
          final safeCopyOfResultErrors =
              seedCopy + [ContError(error, st)];
          seed = safeCopyOfResultErrors;
        }

        if (i >= list.length) {
          observer.onTerminate(seed!);
          return;
        }
      }
    }
  });
}

/// Parallel execution with quit-fast behavior.
///
/// Runs all in parallel, terminates immediately on first failure.
Cont<E, List<A>> _allQuitFast<E, A>(List<Cont<E, A>> list) {
  return Cont.fromRun((runtime, observer) {
    list = list.toList();

    if (list.isEmpty) {
      observer.onValue(<A>[]);
      return;
    }

    bool isDone = false;
    final results = List<A?>.filled(
      list.length,
      null,
    );

    int amountOfFinishedContinuations = 0;

    final ContRuntime<E> sharedContRuntime =
        ContRuntime._(runtime.env(), () {
          return runtime.isCancelled() || isDone;
        });

    void handleTerminate(List<ContError> errors) {
      if (isDone) {
        return;
      }
      isDone = true;

      observer.onTerminate(errors);
    }

    for (final (i, cont) in list.indexed) {
      try {
        cont._run(
          sharedContRuntime,
          ContObserver._(
            (errors) {
              if (sharedContRuntime.isCancelled()) {
                return;
              }
              handleTerminate([
                ...errors,
              ]); // defensive copy
            },
            (a) {
              if (sharedContRuntime.isCancelled()) {
                return;
              }

              results[i] = a;
              amountOfFinishedContinuations += 1;

              if (amountOfFinishedContinuations <
                  list.length) {
                return;
              }

              observer.onValue(results.cast<A>());
            },
          ),
        );
      } catch (error, st) {
        handleTerminate([ContError(error, st)]);
      }
    }
  });
}
