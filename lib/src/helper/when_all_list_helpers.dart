part of '../cont.dart';

void Function() _whenAllPar<P, S>({
  required int total,
  required void Function() Function(
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
    return _voidIgnore;
  }

  // cancelling forwards to every item
  final cancellers = _Cancellers();

  bool isDone = false;

  _Either<(), S> seed = _Left(());
  final List<P> results = [];
  final Map<int, ContCrash> crashes = {};

  // a throw from combine is a crash of the combinator itself, not of an
  // item: once set, combining stops and it is the result once every item
  // has finished, whatever the other outcomes and shouldFavorCrash are
  ContCrash? combineCrash;

  var numberOfFinishedComputations = 0;

  void handleCrash(int index, ContCrash crash) {
    if (isDone) {
      return;
    }
    numberOfFinishedComputations += 1;

    if (numberOfFinishedComputations >= total) {
      isDone = true;

      if (combineCrash case final combineCrash?) {
        onCrash(combineCrash);
        return;
      }

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

      if (combineCrash case final combineCrash?) {
        onCrash(combineCrash);
        return;
      }

      switch (seed) {
        case _Left<(), S>():
          if (crashes.isEmpty) {
            results.add(p);
            onAllPrimary(
              results,
            ); // no copy needed: results is not changed after this
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

      if (combineCrash case final combineCrash?) {
        onCrash(combineCrash);
        return;
      }

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
            ContCrash.tryCatch(() {
              final newSeed = combine(seedValue, s);
              onAnySecondary(newSeed);
            })._ifCrash(onCrash);
          } else {
            if (shouldFavorCrash) {
              final resultCrash = CollectedCrash._(
                Map<int, ContCrash>.from(crashes),
              ); // defensive copy
              onCrash(resultCrash);
            } else {
              ContCrash.tryCatch(() {
                final newSeed = combine(seedValue, s);
                onAnySecondary(newSeed);
              })._ifCrash(onCrash);
            }
          }
      }

      return;
    }

    switch (seed) {
      case _Left<(), S>():
        seed = _Right(s);
      case _Right<(), S>(value: final seedValue):
        if (combineCrash != null) {
          break; // combining stopped after combine threw
        }
        ContCrash.tryCatch(() {
          final newSeed = combine(seedValue, s);
          seed = _Right(newSeed);
        })._ifCrash((crash) {
          combineCrash = crash;
        });
    }
  }

  for (var i = 0; i < total; i++) {
    cancellers.runAlongside(() {
      return onRun(
        i,
        (crash) {
          handleCrash(i, crash);
        },
        handlePrimary,
        (secondary) {
          handleSecondary(i, secondary);
        },
      );
    });
  }

  return cancellers.cancel;
}

Cont<E, F, List<A>> _whenAllAll<E, F, A>(
  List<Cont<E, F, A>> list,
  F Function(F acc, F error) combine,
  bool shouldFavorCrash,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((env, observer) {
    list = list.toList(); // another defensive copy
    return _whenAllPar<A, F>(
      shouldFavorCrash: shouldFavorCrash,
      total: list.length,
      onRun: (index, onCrash, onPrimary, onSecondary) {
        final cont = list[index];
        void Function() canceller = _voidIgnore;
        ContCrash.tryCatch(() {
          canceller = cont.runWith(
            env,
            observer.copyUpdate(
              onCrash: (crash) {
                onCrash(crash);
              },
              onElse: (error) {
                onSecondary(error);
              },
              onThen: (a) {
                onPrimary(a);
              },
            ),
          );
        })._ifCrash(onCrash);
        return canceller;
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
  return Cont.fromRun((env, observer) {
    list = list.toList(); // defensive copy

    if (list.isEmpty) {
      observer.onCrash(CollectedCrash._({}));
      return _voidIgnore;
    }

    // cancelling forwards to every item
    final cancellers = _Cancellers();
    final total = list.length;
    bool isDone = false;
    int numberOfFinished = 0;
    final crashes = <int, ContCrash>{};
    _Either<(), A> thenAcc = _Left(());
    _Either<(), F> elseAcc = _Left(());

    // a throw from combineThenVals or combineElseVals is a crash of the
    // combinator itself, not of an item: once set, combining stops and it
    // is the result once every item has finished
    ContCrash? combineCrash;

    void onAllFinished() {
      if (combineCrash case final combineCrash?) {
        observer.onCrash(combineCrash);
        return;
      }
      if (crashes.length >= total) {
        observer.onCrash(
          CollectedCrash._(Map.from(crashes)),
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
          break; // unreachable: crashes.length < total implies an item succeeded or failed
      }
    }

    void handleThen(int index, A a) {
      if (isDone) return;
      numberOfFinished += 1;
      switch (thenAcc) {
        case _Left():
          thenAcc = _Right(a);
        case _Right(value: final prev):
          if (combineCrash != null) {
            break; // combining stopped after a combine threw
          }
          ContCrash.tryCatch(() {
            thenAcc = _Right(combineThenVals(prev, a));
          })._ifCrash((crash) {
            combineCrash = crash;
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
          if (combineCrash != null) {
            break; // combining stopped after a combine threw
          }
          ContCrash.tryCatch(() {
            elseAcc = _Right(combineElseVals(prev, f));
          })._ifCrash((crash) {
            combineCrash = crash;
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
        cancellers.runAlongside(() {
          return list[idx].runWith(
            env,
            observer.copyUpdate(
              onCrash: (crash) {
                handleCrash(idx, crash);
              },
              onElse: (f) {
                handleElse(idx, f);
              },
              onThen: (a) {
                handleThen(idx, a);
              },
            ),
          );
        });
      })._ifCrash((crash) {
        handleCrash(idx, crash);
      });
    }

    return cancellers.cancel;
  });
}

Cont<E, List<F>, A> _whenAllAny<E, F, A>(
  List<Cont<E, F, A>> list,
  A Function(A acc, A value) combine,
  bool shouldFavorCrash,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((env, observer) {
    list = list.toList(); // another defensive copy
    return _whenAllPar<F, A>(
      shouldFavorCrash: shouldFavorCrash,
      total: list.length,
      onRun: (index, onCrash, onPrimary, onSecondary) {
        final cont = list[index];

        void Function() canceller = _voidIgnore;
        ContCrash.tryCatch(() {
          canceller = cont.runWith(
            env,
            observer.copyUpdate(
              onCrash: (crash) {
                onCrash(crash);
              },
              onElse: (error) {
                onPrimary(error);
              },
              onThen: (a) {
                onSecondary(a);
              },
            ),
          );
        })._ifCrash(onCrash);
        return canceller;
      },
      combine: combine,
      onAllPrimary: observer.onElse,
      onAnySecondary: observer.onThen,
      onCrash: observer.onCrash,
    );
  });
}
