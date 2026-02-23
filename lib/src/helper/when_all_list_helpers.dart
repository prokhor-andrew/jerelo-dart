part of '../cont.dart';

void _whenAllPar<P, S>({
  required int total,
  required void Function(
    int index,
    void Function(ContCrash) onCrash,
    void Function(P) onPrimary,
    void Function(S) onSecondary,
  ) onRun,
  required S Function(S acc, S next) combine,
  required void Function(List<P> primaries) onAllPrimary,
  required void Function(S secondary) onAnySecondary,
  required void Function(ContCrash crash) onCrash,
  required bool shouldFavorCrash,
}) {
  if (total <= 0) {
    onAllPrimary([]);
    return;
  }

  bool isDone = false;

  _Either<(), S> seed = _Left(());
  final List<P> results = [];
  final Map<int, ContCrash> crashes = {};

  var numberOfFinishedComputations = 0;

  void handleCrash(int index, ContCrash crash) {
    if (isDone) {
      return;
    }
    numberOfFinishedComputations += 1;

    if (numberOfFinishedComputations >= total) {
      isDone = true;

      switch (seed) {
        case _Left<(), S>():
          crashes[index] = crash;
          final resultCrash = CollectedCrash._(
            Map<int, ContCrash>.from(crashes),
          ); // defensive copy
          onCrash(resultCrash);
        case _Right<(), S>(value: final seedValue):
          if (shouldFavorCrash) {
            crashes[index] = crash;
            final resultCrash = CollectedCrash._(
              Map<int, ContCrash>.from(crashes),
            ); // defensive copy
            onCrash(resultCrash);
          } else {
            onAnySecondary(seedValue);
          }
      }

      return;
    }

    crashes[index] = crash;
  }

  void handlePrimary(P p) {
    if (isDone) {
      return;
    }
    numberOfFinishedComputations += 1;

    if (numberOfFinishedComputations >= total) {
      isDone = true;
      switch (seed) {
        case _Left<(), S>():
          if (crashes.isEmpty) {
            results.add(p);
            onAllPrimary(
              results,
            ); // defensive copy
          } else {
            final resultCrash = CollectedCrash._(
              Map<int, ContCrash>.from(crashes),
            ); // defensive copy
            onCrash(resultCrash);
          }
        case _Right<(), S>(value: final seedValue):
          if (crashes.isNotEmpty) {
            if (shouldFavorCrash) {
              final resultCrash = CollectedCrash._(
                Map<int, ContCrash>.from(crashes),
              ); // defensive copy
              onCrash(resultCrash);
            } else {
              onAnySecondary(seedValue);
            }
          } else {
            onAnySecondary(seedValue);
          }
      }
      return;
    }

    results.add(p);
  }

  void handleSecondary(int i, S s) {
    if (isDone) {
      return;
    }

    numberOfFinishedComputations += 1;

    if (numberOfFinishedComputations >= total) {
      isDone = true;

      switch (seed) {
        case _Left<(), S>():
          if (crashes.isEmpty) {
            onAnySecondary(s);
          } else {
            if (shouldFavorCrash) {
              final resultCrash = CollectedCrash._(
                Map<int, ContCrash>.from(crashes),
              ); // defensive copy
              onCrash(resultCrash);
            } else {
              onAnySecondary(s);
            }
          }
        case _Right<(), S>(value: final seedValue):
          if (crashes.isEmpty) {
            final crash = ContCrash.tryCatch(() {
              final newSeed = combine(seedValue, s);
              onAnySecondary(newSeed);
            });
            if (crash != null) {
              if (shouldFavorCrash) {
                onCrash(crash);
              } else {
                onAnySecondary(seedValue);
              }
            }
          } else {
            if (shouldFavorCrash) {
              final resultCrash = CollectedCrash._(
                Map<int, ContCrash>.from(crashes),
              ); // defensive copy
              onCrash(resultCrash);
            } else {
              final crash = ContCrash.tryCatch(() {
                final newSeed = combine(seedValue, s);
                onAnySecondary(newSeed);
              });
              if (crash != null) {
                onAnySecondary(
                    seedValue); // we ignore crash, as we favor secondary
              }
            }
          }
      }

      return;
    }

    switch (seed) {
      case _Left<(), S>():
        seed = _Right(s);
      case _Right<(), S>(value: final seedValue):
        final crash = ContCrash.tryCatch(() {
          final newSeed = combine(seedValue, s);
          seed = _Right(newSeed);
        });
        if (crash != null) {
          crashes[i] = crash;
        }
    }
  }

  for (var i = 0; i < total; i++) {
    onRun(
      i,
      (crash) {
        handleCrash(i, crash);
      },
      handlePrimary,
      (secondary) {
        handleSecondary(i, secondary);
      },
    );
  }
}

Cont<E, F, List<A>> _whenAllAll<E, F, A>(
  List<Cont<E, F, A>> list,
  F Function(F acc, F error) combine,
  bool shouldFavorCrash,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // another defensive copy
    _whenAllPar<A, F>(
      shouldFavorCrash: shouldFavorCrash,
      total: list.length,
      onRun: (index, onCrash, onPrimary, onSecondary) {
        final cont = list[index].absurdify();
        final crash = ContCrash.tryCatch(() {
          cont.runWith(
            runtime,
            observer.copyUpdate(
              onCrash: (crash) {
                if (runtime.isCancelled()) {
                  return;
                }
                onCrash(crash);
              },
              onElse: (error) {
                if (runtime.isCancelled()) {
                  return;
                }
                onSecondary(error);
              },
              onThen: (a) {
                if (runtime.isCancelled()) {
                  return;
                }
                onPrimary(a);
              },
            ),
          );
        });
        if (crash != null) {
          onCrash(crash);
        }
      },
      combine: combine,
      onAllPrimary: observer.onThen,
      onAnySecondary: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}

Cont<E, List<F>, A> _whenAllAny<E, F, A>(
  List<Cont<E, F, A>> list,
  A Function(A acc, A value) combine,
  bool shouldFavorCrash,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // another defensive copy
    _whenAllPar<F, A>(
      shouldFavorCrash: shouldFavorCrash,
      total: list.length,
      onRun: (index, onCrash, onPrimary, onSecondary) {
        final cont = list[index].absurdify();

        final crash = ContCrash.tryCatch(() {
          cont.runWith(
            runtime,
            observer.copyUpdate(
              onCrash: (crash) {
                if (runtime.isCancelled()) {
                  return;
                }
                onCrash(crash);
              },
              onElse: (error) {
                if (runtime.isCancelled()) {
                  return;
                }
                onPrimary(error);
              },
              onThen: (a) {
                if (runtime.isCancelled()) {
                  return;
                }
                onSecondary(a);
              },
            ),
          );
        });
        if (crash != null) {
          onCrash(crash);
        }
      },
      combine: combine,
      onAllPrimary: observer.onElse,
      onAnySecondary: observer.onThen,
      onCrash: observer.onCrash,
    );
  });
}
