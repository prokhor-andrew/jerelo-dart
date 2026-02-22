part of '../cont.dart';

Cont<E, F, A3> _bothQuitFast<E, F, A1, A2, A3>(
  Cont<E, F, A1> left,
  Cont<E, F, A2> right,
  A3 Function(A1 a1, A2 a2) combine,
) {
  return Cont.fromRun((runtime0, observer) {
    final (
      runtime,
      handleCrash,
      handleError,
      handleValue,
    ) = _quitFast<E, A1, A2, A3, F>(
      runtime: runtime0,
      combine: combine,
      onPrimary: observer.onElse,
      onSecondary: observer.onThen,
      onCrash: observer.onCrash,
    );

    final leftCrash = ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer
            .copyUpdateOnCrash(handleCrash)
            .copyUpdateOnThen<A1>((a) {
          handleValue(_Left(a));
        }).copyUpdateOnElse<F>(handleError),
      );
    });

    if (leftCrash != null) {
      handleCrash(leftCrash);
    }

    final rightCrash = ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer
            .copyUpdateOnCrash(handleCrash)
            .copyUpdateOnThen<A2>((a) {
          handleValue(_Right(a));
        }).copyUpdateOnElse(handleError),
      );
    });
    if (rightCrash != null) {
      handleCrash(rightCrash);
    }
  });
}

Cont<E, F3, A> _eitherQuitFast<E, F1, F2, F3, A>(
  Cont<E, F1, A> left,
  Cont<E, F2, A> right,
  F3 Function(F1 f1, F2 f2) combine,
) {
  return Cont.fromRun((runtime0, observer) {
    final (
      runtime,
      handleCrash,
      handleValue,
      handleError,
    ) = _quitFast<E, F1, F2, F3, A>(
      runtime: runtime0,
      combine: combine,
      onPrimary: observer.onThen,
      onSecondary: observer.onElse,
      onCrash: observer.onCrash,
    );

    final leftCrash = ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer
            .copyUpdateOnCrash(handleCrash)
            .copyUpdateOnThen(handleValue)
            .copyUpdateOnElse((f1) {
          handleError(_Left(f1));
        }),
      );
    });
    if (leftCrash != null) {
      handleCrash(leftCrash);
    }

    final rightCrash = ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer
            .copyUpdateOnCrash(handleCrash)
            .copyUpdateOnThen(handleValue)
            .copyUpdateOnElse((f2) {
          handleError(_Right(f2));
        }),
      );
    });

    if (rightCrash != null) {
      handleCrash(rightCrash);
    }
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
            final crash = ContCrash.tryCatch(() {
              final f3 = combine(f1, f2);
              onSecondary(f3);
            });
            if (crash != null) {
              onCrash(crash);
            }
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
            final crash = ContCrash.tryCatch(() {
              final f3 = combine(f1, f2);
              onSecondary(f3);
            });
            if (crash != null) {
              onCrash(crash);
            }

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
