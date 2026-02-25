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
          final resultCrash = CollectedCrash(
            Map<int, ContCrash>.from(crashes),
          ); // defensive copy
          onCrash(resultCrash);
        case _Right<(), S>(value: final seedValue):
          if (shouldFavorCrash) {
            crashes[index] = crash;
            final resultCrash = CollectedCrash(
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
            final resultCrash = CollectedCrash(
              Map<int, ContCrash>.from(crashes),
            ); // defensive copy
            onCrash(resultCrash);
          }
        case _Right<(), S>(value: final seedValue):
          if (crashes.isNotEmpty) {
            if (shouldFavorCrash) {
              final resultCrash = CollectedCrash(
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
              final resultCrash = CollectedCrash(
                Map<int, ContCrash>.from(crashes),
              ); // defensive copy
              onCrash(resultCrash);
            } else {
              onAnySecondary(s);
            }
          }
        case _Right<(), S>(value: final seedValue):
          if (crashes.isEmpty) {
            ContCrash.tryCatch(() {
              final newSeed = combine(seedValue, s);
              onAnySecondary(newSeed);
            }).match((_) {}, (crash) {
              if (shouldFavorCrash) {
                onCrash(crash);
              } else {
                onAnySecondary(seedValue);
              }
            });
          } else {
            if (shouldFavorCrash) {
              final resultCrash = CollectedCrash(
                Map<int, ContCrash>.from(crashes),
              ); // defensive copy
              onCrash(resultCrash);
            } else {
              ContCrash.tryCatch(() {
                final newSeed = combine(seedValue, s);
                onAnySecondary(newSeed);
              }).match((_) {}, (_) {
                onAnySecondary(
                  seedValue,
                ); // we ignore crash, as we favor secondary
              });
            }
          }
      }

      return;
    }

    switch (seed) {
      case _Left<(), S>():
        seed = _Right(s);
      case _Right<(), S>(value: final seedValue):
        ContCrash.tryCatch(() {
          final newSeed = combine(seedValue, s);
          seed = _Right(newSeed);
        }).match((_) {}, (crash) {
          crashes[i] = crash;
        });
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
        ContCrash.tryCatch(() {
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
        }).match((_) {}, onCrash);
      },
      combine: combine,
      onAllPrimary: observer.onThen,
      onAnySecondary: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}

Cont<E, F, A> _convergeCrashRunAll<E, F, A>(
  List<Cont<E, F, A>> list,
  A Function(A a1, A a2) combineThenVals,
  F Function(F f1, F f2) combineElseVals,
  bool shouldFavorElse,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy

    if (list.isEmpty) {
      observer.onCrash(CollectedCrash({}));
      return;
    }

    final total = list.length;
    bool isDone = false;
    int numberOfFinished = 0;
    final crashes = <int, ContCrash>{};
    _Either<(), A> thenAcc = _Left(());
    _Either<(), F> elseAcc = _Left(());

    void onAllFinished() {
      if (crashes.length >= total) {
        observer.onCrash(
          CollectedCrash(Map.from(crashes)),
        );
        return;
      }
      switch ((thenAcc, elseAcc)) {
        case (
            _Right(value: final a),
            _Right(value: final f)
          ):
          if (shouldFavorElse) {
            observer.onElse(f);
          } else {
            observer.onThen(a);
          }
        case (_Right(value: final a), _Left()):
          observer.onThen(a);
        case (_Left(), _Right(value: final f)):
          observer.onElse(f);
        case (_Left(), _Left()):
          break; // unreachable: crashes.length < total implies hasThen || hasElse
      }
    }

    void handleThen(int index, A a) {
      if (isDone) return;
      numberOfFinished += 1;
      switch (thenAcc) {
        case _Left():
          thenAcc = _Right(a);
        case _Right(value: final prev):
          ContCrash.tryCatch(() {
            thenAcc = _Right(combineThenVals(prev, a));
          }).match((_) {}, (crash) {
            crashes[index] = crash;
          });
      }
      if (numberOfFinished >= total) {
        isDone = true;
        onAllFinished();
      }
    }

    void handleElse(int index, F f) {
      if (isDone) return;
      numberOfFinished += 1;
      switch (elseAcc) {
        case _Left():
          elseAcc = _Right(f);
        case _Right(value: final prev):
          ContCrash.tryCatch(() {
            elseAcc = _Right(combineElseVals(prev, f));
          }).match((_) {}, (crash) {
            crashes[index] = crash;
          });
      }
      if (numberOfFinished >= total) {
        isDone = true;
        onAllFinished();
      }
    }

    void handleCrash(int index, ContCrash crash) {
      if (isDone) return;
      numberOfFinished += 1;
      crashes[index] = crash;
      if (numberOfFinished >= total) {
        isDone = true;
        onAllFinished();
      }
    }

    for (var i = 0; i < total; i++) {
      final idx = i;
      ContCrash.tryCatch(() {
        list[idx].absurdify().runWith(
              runtime,
              observer.copyUpdate(
                onCrash: (crash) {
                  if (runtime.isCancelled()) return;
                  handleCrash(idx, crash);
                },
                onElse: (f) {
                  if (runtime.isCancelled()) return;
                  handleElse(idx, f);
                },
                onThen: (a) {
                  if (runtime.isCancelled()) return;
                  handleThen(idx, a);
                },
              ),
            );
      }).match((_) {}, (crash) {
        handleCrash(idx, crash);
      });
    }
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

        ContCrash.tryCatch(() {
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
        }).match((_) {}, onCrash);
      },
      combine: combine,
      onAllPrimary: observer.onElse,
      onAnySecondary: observer.onThen,
      onCrash: observer.onCrash,
    );
  });
}
