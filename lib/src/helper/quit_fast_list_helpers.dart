part of '../cont.dart';

void _quitFastPar<E, QF, C>({
  required ContRuntime<E> runtime,
  required int total,
  required void Function(
    int index,
    ContRuntime<E> sharedRuntime,
    void Function(QF) onQuitFast,
    void Function(C) onCollect,
    void Function(ContCrash) onCrash,
  ) onRun,
  required void Function(QF value) onFirstQuitFast,
  required void Function(List<C> collected) onAllCollected,
  required void Function(ContCrash crash) onCrash,
}) {
  if (total <= 0) {
    onAllCollected([]);
    return;
  }

  bool isDone = false;
  final collectedResults = List<C?>.filled(total, null);
  int amountOfCollected = 0;

  final shared = runtime.extendCancellation(() {
    return isDone;
  });

  void handleQuitFast(QF value) {
    if (shared.isCancelled()) {
      return;
    }
    // already checked by shared.isCancelled() that isDone == false
    isDone = true;
    onFirstQuitFast(value);
  }

  void handleCollect(C value, int i) {
    if (shared.isCancelled()) {
      return;
    }

    // already checked by shared.isCancelled() that isDone == false
    collectedResults[i] = value;
    amountOfCollected += 1;
    if (amountOfCollected < total) {
      // keep collecting
      return;
    }
    onAllCollected(collectedResults.cast<C>());
  }

  void handleCrash(ContCrash crash) {
    if (shared.isCancelled()) {
      return;
    }
    // already checked by shared.isCancelled() that isDone == false
    isDone = true;
    onCrash(crash);
  }

  for (int i = 0; i < total; i++) {
    onRun(
      i,
      shared,
      handleQuitFast,
      (c) {
        handleCollect(c, i);
      },
      handleCrash,
    );
  }
}

Cont<E, F, List<A>> _quitFastAll<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((runtime, observer) {
    list = list.toList();
    _quitFastPar<E, F, A>(
      runtime: runtime,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect, onCrash) {
        ContCrash.tryCatch(() {
          list[i].absurdify().runWith(
                shared,
                observer.copyUpdate(
                  onCrash: onCrash,
                  onElse: onQuitFast,
                  onThen: onCollect,
                ),
              );
        }).match((_) {}, onCrash);
      },
      onFirstQuitFast: observer.onElse,
      onAllCollected: observer.onThen,
      onCrash: observer.onCrash,
    );
  });
}

Cont<E, F, A> _convergeCrashQuitFast<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList(); // defensive copy
  return Cont.fromRun((runtime, observer) {
    list = list.toList(); // defensive copy

    if (list.isEmpty) {
      observer.onCrash(CollectedCrash._({}));
      return;
    }

    final total = list.length;
    bool isDone = false;
    int numberOfCrashed = 0;
    final crashes = <int, ContCrash>{};

    final shared = runtime.extendCancellation(() => isDone);

    void handleThen(A a) {
      if (shared.isCancelled()) return;
      isDone = true;
      observer.onThen(a);
    }

    void handleElse(F f) {
      if (shared.isCancelled()) return;
      isDone = true;
      observer.onElse(f);
    }

    void handleCrash(int index, ContCrash crash) {
      if (shared.isCancelled()) return;
      crashes[index] = crash;
      numberOfCrashed += 1;
      if (numberOfCrashed >= total) {
        isDone = true;
        observer.onCrash(
          CollectedCrash._(Map.from(crashes)),
        );
      }
    }

    for (var i = 0; i < total; i++) {
      final idx = i;
      ContCrash.tryCatch(() {
        list[idx].absurdify().runWith(
              shared,
              observer.copyUpdate(
                onCrash: (c) => handleCrash(idx, c),
                onElse: handleElse,
                onThen: handleThen,
              ),
            );
      }).match((_) {}, (crash) {
        handleCrash(idx, crash);
      });
    }
  });
}

Cont<E, List<F>, A> _quitFastAny<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((runtime, observer) {
    list = list.toList();
    _quitFastPar<E, A, F>(
      runtime: runtime,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect, onCrash) {
        ContCrash.tryCatch(() {
          list[i].absurdify().runWith(
                shared,
                observer.copyUpdate(
                  onCrash: onCrash,
                  onThen: onQuitFast,
                  onElse: onCollect,
                ),
              );
        }).match((_) {}, onCrash);
      },
      onFirstQuitFast: observer.onThen,
      onAllCollected: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}
