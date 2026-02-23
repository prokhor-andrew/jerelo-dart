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
        final crash = ContCrash.tryCatch(() {
          list[i].absurdify().runWith(
                shared,
                observer.copyUpdate(
                  onCrash: onCrash,
                  onElse: onQuitFast,
                  onThen: onCollect,
                ),
              );
        });
        if (crash != null) {
          onCrash(crash);
        }
      },
      onFirstQuitFast: observer.onElse,
      onAllCollected: observer.onThen,
      onCrash: observer.onCrash,
    );
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
        final crash = ContCrash.tryCatch(() {
          list[i].absurdify().runWith(
                shared,
                observer.copyUpdate(
                  onCrash: onCrash,
                  onThen: onQuitFast,
                  onElse: onCollect,
                ),
              );
        });
        if (crash != null) {
          onCrash(crash);
        }
      },
      onFirstQuitFast: observer.onThen,
      onAllCollected: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}
