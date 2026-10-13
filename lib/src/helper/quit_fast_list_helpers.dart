part of '../cont.dart';

void _quitFastPar<E, QF, C>({
  required E env,
  required int total,
  required void Function(
    int index,
    E sharedEnv,
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

  final collectedResults = List<C?>.filled(total, null);
  int amountOfCollected = 0;

  // set once the result is decided; later outcomes are ignored
  bool isDone = false;

  void handleQuitFast(QF value) {
    if (isDone) {
      return;
    }
    isDone = true;
    onFirstQuitFast(value);
  }

  void handleCollect(C value, int i) {
    if (isDone) {
      return;
    }

    collectedResults[i] = value;
    amountOfCollected += 1;
    if (amountOfCollected < total) {
      // keep collecting
      return;
    }
    isDone = true;
    onAllCollected(collectedResults.cast<C>());
  }

  void handleCrash(ContCrash crash) {
    if (isDone) {
      return;
    }
    isDone = true;
    onCrash(crash);
  }

  for (int i = 0; i < total; i++) {
    onRun(
      i,
      env,
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
  return Cont.fromRun((env, observer) {
    list = list.toList();
    _quitFastPar<E, F, A>(
      env: env,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect, onCrash) {
        ContCrash.tryCatch(() {
          list[i].runWith(
            shared,
            observer.copyUpdate(
              onCrash: onCrash,
              onElse: onQuitFast,
              onThen: onCollect,
            ),
          );
        })._ifCrash(onCrash);
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
  return Cont.fromRun((env, observer) {
    list = list.toList(); // defensive copy

    if (list.isEmpty) {
      observer.onCrash(CollectedCrash._({}));
      return;
    }

    final total = list.length;
    int numberOfCrashed = 0;
    final crashes = <int, ContCrash>{};

    // set once the result is decided; later outcomes are ignored
    bool isDone = false;

    void handleThen(A a) {
      if (isDone) return;
      isDone = true;
      observer.onThen(a);
    }

    void handleElse(F f) {
      if (isDone) return;
      isDone = true;
      observer.onElse(f);
    }

    void handleCrash(int index, ContCrash crash) {
      if (isDone) return;
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
      ContCrash.tryCatch(() {
        list[i].runWith(
          env,
          observer.copyUpdate(
            onCrash: (c) => handleCrash(i, c),
            onElse: handleElse,
            onThen: handleThen,
          ),
        );
      })._ifCrash((crash) {
        handleCrash(i, crash);
      });
    }
  });
}

Cont<E, List<F>, A> _quitFastAny<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((env, observer) {
    list = list.toList();
    _quitFastPar<E, A, F>(
      env: env,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect, onCrash) {
        ContCrash.tryCatch(() {
          list[i].runWith(
            shared,
            observer.copyUpdate(
              onCrash: onCrash,
              onThen: onQuitFast,
              onElse: onCollect,
            ),
          );
        })._ifCrash(onCrash);
      },
      onFirstQuitFast: observer.onThen,
      onAllCollected: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}
