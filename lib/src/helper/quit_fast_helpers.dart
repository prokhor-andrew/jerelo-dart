part of '../cont.dart';

Cont<E, F, A3> _bothQuitFast<E, F, A1, A2, A3>(
  Cont<E, F, A1> left,
  Cont<E, F, A2> right,
  A3 Function(A1 a1, A2 a2) combine,
) {
  // no absurdify, as they were absurdified before
  return Cont.fromRun((runtime0, observer) {
    final (
      runtime,
      handleCrash,
      handleElse,
      handleThen,
    ) = _quitFast<E, A1, A2, A3, F>(
      runtime: runtime0,
      combine: combine,
      onPrimary: observer.onElse,
      onSecondary: observer.onThen,
      onCrash: observer.onCrash,
    );

    ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer.copyUpdate(
          onCrash: handleCrash,
          onElse: handleElse,
          onThen: (a) {
            handleThen(_Left(a));
          },
        ),
      );
    }).match((_) {}, handleCrash);

    ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer.copyUpdate(
          onCrash: handleCrash,
          onElse: handleElse,
          onThen: (a) {
            handleThen(_Right(a));
          },
        ),
      );
    }).match((_) {}, handleCrash);
  });
}

Cont<E, F3, A> _eitherQuitFast<E, F1, F2, F3, A>(
  Cont<E, F1, A> left,
  Cont<E, F2, A> right,
  F3 Function(F1 f1, F2 f2) combine,
) {
  // no absurdify, as they were absurdified before
  return Cont.fromRun((runtime0, observer) {
    final (
      runtime,
      handleCrash,
      handleThen,
      handleElse,
    ) = _quitFast<E, F1, F2, F3, A>(
      runtime: runtime0,
      combine: combine,
      onPrimary: observer.onThen,
      onSecondary: observer.onElse,
      onCrash: observer.onCrash,
    );

    ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer.copyUpdate(
          onCrash: handleCrash,
          onElse: ((f1) {
            handleElse(_Left(f1));
          }),
          onThen: handleThen,
        ),
      );
    }).match((_) {}, handleCrash);

    ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer.copyUpdate(
          onCrash: handleCrash,
          onElse: ((f2) {
            handleElse(_Right(f2));
          }),
          onThen: handleThen,
        ),
      );
    }).match((_) {}, handleCrash);
  });
}

Cont<E, F, A> _crashQuitFast<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right,
) {
  // no absurdify, as they were absurdified before
  return Cont.fromRun((runtime0, observer) {
    final _QuitFastStateHolder<ContCrash, ContCrash>
        holder = _QuitFastStateHolder();

    final runtime = runtime0.extendCancellation(() {
      return holder.state == null;
    });

    void handleThen(A a) {
      if (runtime.isCancelled()) {
        return;
      }
      holder.state = null;
      observer.onThen(a);
    }

    void handleElse(F f) {
      if (runtime.isCancelled()) {
        return;
      }
      holder.state = null;
      observer.onElse(f);
    }

    void handleCrash(_Either<ContCrash, ContCrash> either) {
      if (runtime.isCancelled()) {
        return;
      }

      switch (either) {
        case _Left<ContCrash, ContCrash>(value: final c1):
          switch (holder.state) {
            case null:
              break; // cancelled, do nothing
            case _QuitFastStep0<ContCrash, ContCrash>():
              holder.state =
                  _QuitFastLeftSecondaryRightNull(c1);
            case _QuitFastLeftSecondaryRightNull<ContCrash,
                  ContCrash>():
              break; // can't have left crash twice - unreachable state
            case _QuitFastLeftNullRightSecondary<ContCrash,
                  ContCrash>(f2: final c2):
              holder.state = null;
              observer.onCrash(MergedCrash._(c1, c2));
          }
        case _Right<ContCrash, ContCrash>(value: final c2):
          switch (holder.state) {
            case null:
              break; // cancelled, do nothing
            case _QuitFastStep0<ContCrash, ContCrash>():
              holder.state =
                  _QuitFastLeftNullRightSecondary(c2);
            case _QuitFastLeftSecondaryRightNull<ContCrash,
                  ContCrash>(f1: final c1):
              holder.state = null;
              observer.onCrash(MergedCrash._(c1, c2));
            case _QuitFastLeftNullRightSecondary<ContCrash,
                  ContCrash>():
              break; // can't have right crash twice - unreachable state
          }
      }
    }

    ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer.copyUpdate(
          onCrash: (crash) {
            handleCrash(_Left(crash));
          },
          onElse: handleElse,
          onThen: handleThen,
        ),
      );
    }).match((_) {}, (crash) {
      handleCrash(_Left(crash));
    });

    ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer.copyUpdate(
          onCrash: (crash) {
            handleCrash(_Right(crash));
          },
          onElse: handleElse,
          onThen: handleThen,
        ),
      );
    }).match((_) {}, (crash) {
      handleCrash(_Right(crash));
    });
  });
}

(
  ContRuntime<E> runtime,
  void Function(ContCrash) handleCrash,
  void Function(A a) handlePrimary,
  void Function(_Either<F1, F2> either) handleSecondary,
) _quitFast<E, F1, F2, F3, A>({
  required ContRuntime<E> runtime,
  required F3 Function(F1 f1, F2 f2) combine,
  required void Function(A a) onPrimary,
  required void Function(F3 f3) onSecondary,
  required void Function(ContCrash crash) onCrash,
}) {
  final _QuitFastStateHolder<F1, F2> holder =
      _QuitFastStateHolder();

  runtime = runtime.extendCancellation(() {
    return holder.state == null;
  });

  void handleCrash(ContCrash crash) {
    if (runtime.isCancelled()) {
      return;
    }
    holder.state = null;
    onCrash(crash);
  }

  void handlePrimary(A a) {
    if (runtime.isCancelled()) {
      return;
    }

    holder.state = null;
    onPrimary(a);
  }

  void handleSecondary(_Either<F1, F2> either) {
    if (runtime.isCancelled()) {
      return;
    }

    switch (either) {
      case _Left<F1, F2>(value: final f1):
        switch (holder.state) {
          case null:
            break; // cancelled, do nothing
          case _QuitFastStep0<F1, F2>():
            holder.state = _QuitFastLeftSecondaryRightNull(
              f1,
            );
          case _QuitFastLeftSecondaryRightNull<F1, F2>():
            break; // we can't have left secondary and get another left secondary - unreachable state
          case _QuitFastLeftNullRightSecondary<F1, F2>(
              f2: final f2
            ):
            holder.state = null;
            ContCrash.tryCatch(() {
              final f3 = combine(f1, f2);
              onSecondary(f3);
            }).match((_) {}, onCrash);
        }
      case _Right<F1, F2>(value: final f2):
        switch (holder.state) {
          case null: // cancelled, do nothing
            break;
          case _QuitFastStep0<F1, F2>():
            holder.state = _QuitFastLeftNullRightSecondary(
              f2,
            );
          case _QuitFastLeftSecondaryRightNull<F1, F2>(
              f1: final f1
            ):
            holder.state = null;
            ContCrash.tryCatch(() {
              final f3 = combine(f1, f2);
              onSecondary(f3);
            }).match((_) {}, onCrash);

          case _QuitFastLeftNullRightSecondary<F1, F2>():
            break; // we can't have right secondary and get another right secondary - unreachable state
        }
    }
  }

  return (
    runtime,
    handleCrash,
    handlePrimary,
    handleSecondary
  );
}

final class _QuitFastStateHolder<F1, F2> {
  _QuitFastStep<F1, F2>? state = const _QuitFastStep0();

  _QuitFastStateHolder();
}

sealed class _QuitFastStep<F1, F2> {
  const _QuitFastStep();
}

final class _QuitFastStep0<F1, F2>
    extends _QuitFastStep<F1, F2> {
  const _QuitFastStep0();
}

final class _QuitFastLeftSecondaryRightNull<F1, F2>
    extends _QuitFastStep<F1, F2> {
  final F1 f1;
  const _QuitFastLeftSecondaryRightNull(this.f1);
}

final class _QuitFastLeftNullRightSecondary<F1, F2>
    extends _QuitFastStep<F1, F2> {
  final F2 f2;
  const _QuitFastLeftNullRightSecondary(this.f2);
}
