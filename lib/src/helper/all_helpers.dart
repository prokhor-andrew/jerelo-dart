part of '../cont.dart';

/// Implementation of `all` with the sequence policy.
///
/// Runs each continuation in [list] one after another using a stack-safe
/// loop. Accumulates results into a list. Stops at the first termination
/// and propagates its errors.
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
              return _StackSafeLoopPolicyStop(_Left(()));
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

                callback(_Left((i + 1, [...values, a])));
              },
              //
            ),
          );
        } catch (error, st) {
          callback(
            _Right([ContError.withStackTrace(error, st)]),
          );
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
                observer.onThen(results);
                return;
              case _Right(value: final errors):
                observer.onElse(errors);
                return;
            }
        }
      },
      //
    );
  });
}

/// Implementation of `all` with the merge-when-all policy.
///
/// Runs all continuations in [list] in parallel and waits for every one to
/// complete. If all succeed, collects their values into a list. If any
/// terminate, merges all termination errors and propagates them.
Cont<E, List<A>> _allMergeWhenAll<E, A>(
  List<Cont<E, A>> list,
) {
  return Cont.fromRun((runtime, observer) {
    list = list.toList();

    if (list.isEmpty) {
      observer.onThen(<A>[]);
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
              observer.onElse([...errors]);
            },
            (a) {
              if (runtime.isCancelled()) {
                return;
              }
              observer.onThen([a]);
            },
          ),
        );
      } catch (error, st) {
        observer.onElse([
          ContError.withStackTrace(error, st),
        ]);
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
                observer.onElse(seed!);
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
                  observer.onElse(seedCopy);
                }
                return;
              }

              results.add(a);
              if (i >= list.length) {
                observer.onThen(results);
              }
            },
          ),
          //
        );
      } catch (error, st) {
        i += 1;
        final seedCopy = seed;
        if (seedCopy == null) {
          seed = [ContError.withStackTrace(error, st)];
        } else {
          final safeCopyOfResultErrors =
              seedCopy +
              [ContError.withStackTrace(error, st)];
          seed = safeCopyOfResultErrors;
        }

        if (i >= list.length) {
          observer.onElse(seed!);
          return;
        }
      }
    }
  });
}

/// Implementation of `all` with the quit-fast policy.
///
/// Runs all continuations in [list] in parallel with a shared runtime that
/// reports cancellation as soon as any continuation terminates. If all
/// succeed, collects values preserving order. If any terminates, the others
/// are effectively cancelled and the errors are propagated immediately.
Cont<E, List<A>> _allQuitFast<E, A>(List<Cont<E, A>> list) {
  return Cont.fromRun((runtime, observer) {
    list = list.toList();

    if (list.isEmpty) {
      observer.onThen(<A>[]);
      return;
    }

    bool isDone = false;
    final results = List<A?>.filled(list.length, null);

    int amountOfFinishedContinuations = 0;

    final ContRuntime<E> sharedContRuntime = ContRuntime._(
      runtime.env(),
      () {
        return runtime.isCancelled() || isDone;
      },
      runtime.onPanic,
    );

    void handleTerminate(List<ContError> errors) {
      if (isDone) {
        return;
      }
      isDone = true;

      observer.onElse(errors);
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

              observer.onThen(results.cast<A>());
            },
          ),
        );
      } catch (error, st) {
        handleTerminate([
          ContError.withStackTrace(error, st),
        ]);
      }
    }
  });
}
