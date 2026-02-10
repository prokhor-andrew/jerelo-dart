part of '../cont.dart';

Cont<E, A> _anySequence<E, A>(List<Cont<E, A>> list) {
  return Cont.fromRun((runtime, observer) {
    final safeCopy = List<Cont<E, A>>.from(list);

    _stackSafeLoop<
      _Either<(int, List<ContError>), _Either<(), A>>,
      (int, List<ContError>),
      _Either<(), _Either<List<ContError>, A>>
    >(
      seed: _Left((0, [])),
      keepRunningIf: (either) {
        switch (either) {
          case _Left(value: final tuple):
            final (index, errors) = tuple;
            if (index >= safeCopy.length) {
              return _StackSafeLoopPolicyStop(
                _Right(_Left(errors)),
              );
            }
            return _StackSafeLoopPolicyKeepRunning((
              index,
              errors,
            ));
          case _Right(value: final either):
            switch (either) {
              case _Left<(), A>():
                return _StackSafeLoopPolicyStop(_Left(()));
              case _Right<(), A>(value: final a):
                return _StackSafeLoopPolicyStop(
                  _Right(_Right(a)),
                );
            }
        }
      },
      computation: (tuple, callback) {
        final (index, errors) = tuple;
        Cont<E, A> cont = safeCopy[index];
        if (cont is Cont<E, Never>) {
          cont = cont.absurd<A>();
        }

        try {
          cont._run(
            runtime,
            ContObserver._(
              (errors2) {
                if (runtime.isCancelled()) {
                  callback(_Right(_Left(())));
                  return;
                }
                callback(
                  _Left((
                    index + 1,
                    [...errors, ...errors2],
                  )),
                );
              },
              (a) {
                if (runtime.isCancelled()) {
                  callback(_Right(_Left(())));
                  return;
                }
                callback(_Right(_Right(a)));
              },
              //
            ),
          );
        } catch (error, st) {
          callback(
            _Left((
              index + 1,
              [
                ...errors,
                ContError.withStackTrace(error, st),
              ],
            )),
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
              case _Left<List<ContError>, A>(
                value: final errors,
              ):
                observer.onTerminate([...errors]);
                return;
              case _Right<List<ContError>, A>(
                value: final a,
              ):
                observer.onValue(a);
                return;
            }
        }
      },
      //
    );
  });
}

Cont<E, A> _anyMergeWhenAll<E, A>(
  List<Cont<E, A>> list,
  A Function(A acc, A value) combine,
) {
  return Cont.fromRun((runtime, observer) {
    final safeCopy = List<Cont<E, A>>.from(list);

    if (safeCopy.isEmpty) {
      observer.onTerminate();
      return;
    }

    if (safeCopy.length == 1) {
      final cont = safeCopy[0];
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
              observer.onValue(a);
            },
          ),
        );
      } catch (error, st) {
        observer.onTerminate([
          ContError.withStackTrace(error, st),
        ]);
      }
      return;
    }

    A? seed;

    final List<ContError> errors = [];

    var i = 0;

    void handleTermination(
      List<ContError> terminateErrors,
    ) {
      if (runtime.isCancelled()) {
        return;
      }
      i += 1;
      final seedCopy = seed;
      if (seedCopy != null) {
        if (i >= safeCopy.length) {
          observer.onValue(seedCopy);
        }
        return;
      }

      errors.addAll(terminateErrors);
      if (i >= safeCopy.length) {
        observer.onTerminate(errors);
      }
    }

    for (final cont in safeCopy) {
      try {
        cont._run(
          runtime,
          ContObserver._(
            (terminateErrors) {
              if (runtime.isCancelled()) {
                return;
              }
              i += 1;
              final seedCopy = seed;
              if (seedCopy != null) {
                if (i >= safeCopy.length) {
                  observer.onValue(seedCopy);
                }
                return;
              }

              errors.addAll(terminateErrors);
              if (i >= safeCopy.length) {
                observer.onTerminate(errors);
              }
            },
            (a) {
              if (runtime.isCancelled()) {
                return;
              }
              i += 1;
              final seedCopy = seed;
              final A seedCopy2;
              if (seedCopy == null) {
                seed = a;
                seedCopy2 = a;
              } else {
                try {
                  final safeCopyOfResultValue = combine(
                    seedCopy,
                    a,
                  );
                  seed = safeCopyOfResultValue;
                  seedCopy2 = safeCopyOfResultValue;
                } catch (error, st) {
                  i -=
                      1; // we have to remove 1 step, as we gonna increment it again below
                  handleTermination([
                    ContError.withStackTrace(error, st),
                  ]);
                  return;
                }
              }

              if (i >= safeCopy.length) {
                observer.onValue(seedCopy2);
                return;
              }
            },
          ),
          //
        );
      } catch (error, st) {
        i += 1;
        final seedCopy = seed;
        if (seedCopy != null) {
          if (i >= safeCopy.length) {
            observer.onValue(seedCopy);
          }
          return;
        }

        errors.add(ContError.withStackTrace(error, st));

        if (i >= safeCopy.length) {
          observer.onTerminate(errors);
          return;
        }
      }
    }
  });
}

Cont<E, A> _anyQuitFast<E, A>(List<Cont<E, A>> list) {
  return Cont.fromRun((runtime, observer) {
    final safeCopy = List<Cont<E, A>>.from(list);
    if (safeCopy.isEmpty) {
      observer.onTerminate();
      return;
    }

    final List<List<ContError>> resultOfErrors =
        List.generate(safeCopy.length, (_) {
          return [];
        });

    bool isWinnerFound = false;
    int numberOfFinished = 0;

    final ContRuntime<E> sharedContRuntime = ContRuntime._(
      runtime.env(),
      () {
        return runtime.isCancelled() || isWinnerFound;
      },
      runtime.onPanic,
    );

    void handleTerminate(
      int index,
      List<ContError> errors,
    ) {
      numberOfFinished += 1;

      resultOfErrors[index] = errors;

      if (numberOfFinished < safeCopy.length) {
        return;
      }

      final flattened = resultOfErrors.expand((list) {
        return list;
      }).toList();

      observer.onTerminate(flattened);
    }

    for (int i = 0; i < safeCopy.length; i++) {
      final cont = safeCopy[i];
      try {
        cont._run(
          sharedContRuntime,
          ContObserver._(
            (errors) {
              if (sharedContRuntime.isCancelled()) {
                return;
              }
              handleTerminate(i, [
                ...errors,
              ]); // defensive copy
            },
            (a) {
              if (sharedContRuntime.isCancelled()) {
                return;
              }
              isWinnerFound = true;
              observer.onValue(a);
            },
          ),
        );
      } catch (error, st) {
        handleTerminate(i, [
          ContError.withStackTrace(error, st),
        ]);
      }
    }
  });
}
