part of '../cont.dart';

void Function() _quitFastPar<E, QF, C>({
  required E env,
  required int total,
  required void Function() Function(
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
    return _voidIgnore;
  }

  // cancelling forwards to every item; deciding cancels the rest
  final cancellers = _Cancellers();

  final collectedResults = List<C?>.filled(total, null);
  int amountOfCollected = 0;

  // set once the result is decided; later outcomes are ignored
  bool isDone = false;

  void handleQuitFast(QF value) {
    if (isDone) {
      return;
    }
    isDone = true;
    cancellers.cancel();
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
    onAllCollected(List<C>.from(collectedResults));
  }

  void handleCrash(ContCrash crash) {
    if (isDone) {
      return;
    }
    isDone = true;
    cancellers.cancel();
    onCrash(crash);
  }

  for (int i = 0; i < total; i++) {
    cancellers.runAlongside(() {
      return onRun(
        i,
        env,
        handleQuitFast,
        (c) {
          handleCollect(c, i);
        },
        handleCrash,
      );
    });
  }

  return cancellers.cancel;
}

Cont<E, F, List<A>> _quitFastAll<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((env, observer) {
    list = list.toList();
    return _quitFastPar<E, F, A>(
      env: env,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect, onCrash) {
        void Function() canceller = _voidIgnore;
        ContCrash.tryCatch(() {
          canceller = list[i].runWith(
            shared,
            observer.copyUpdate(
              onCrash: onCrash,
              onElse: onQuitFast,
              onThen: onCollect,
            ),
          );
        })._ifCrash(onCrash);
        return canceller;
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
      return _voidIgnore;
    }

    // cancelling forwards to every item; deciding cancels the rest
    final cancellers = _Cancellers();

    final total = list.length;
    int numberOfCrashed = 0;
    final crashes = <int, ContCrash>{};

    // set once the result is decided; later outcomes are ignored
    bool isDone = false;

    void handleThen(A a) {
      if (isDone) return;
      isDone = true;
      cancellers.cancel();
      observer.onThen(a);
    }

    void handleElse(F f) {
      if (isDone) return;
      isDone = true;
      cancellers.cancel();
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
        cancellers.runAlongside(() {
          return list[i].runWith(
            env,
            observer.copyUpdate(
              onCrash: (c) => handleCrash(i, c),
              onElse: handleElse,
              onThen: handleThen,
            ),
          );
        });
      })._ifCrash((crash) {
        handleCrash(i, crash);
      });
    }

    return cancellers.cancel;
  });
}

Cont<E, List<F>, A> _quitFastAny<E, F, A>(
  List<Cont<E, F, A>> list,
) {
  list = list.toList();
  return Cont.fromRun((env, observer) {
    list = list.toList();
    return _quitFastPar<E, A, F>(
      env: env,
      total: list.length,
      onRun: (i, shared, onQuitFast, onCollect, onCrash) {
        void Function() canceller = _voidIgnore;
        ContCrash.tryCatch(() {
          canceller = list[i].runWith(
            shared,
            observer.copyUpdate(
              onCrash: onCrash,
              onThen: onQuitFast,
              onElse: onCollect,
            ),
          );
        })._ifCrash(onCrash);
        return canceller;
      },
      onFirstQuitFast: observer.onThen,
      onAllCollected: observer.onElse,
      onCrash: observer.onCrash,
    );
  });
}
