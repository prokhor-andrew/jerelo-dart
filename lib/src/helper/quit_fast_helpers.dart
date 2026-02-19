part of '../cont.dart';

Cont<E, F, A3> _bothQuitFast<E, F, A1, A2, A3>(
  Cont<E, F, A1> left,
  Cont<E, F, A2> right,
  A3 Function(A1 a1, A2 a2) combine,
) {
  return Cont.fromRun((runtime0, observer) {
    final (runtime, handleError, handleValue) =
        _quitFast<E, A1, A2, A3, ContError<F>>(
      runtime0: runtime0,
      combine: combine,
      onPrimary: observer.onElse,
      onSecondary: observer.onThen,
      onPanic: (error, st) {
        observer.onElse(
          ThrownError.withStackTrace(error, st),
        );
      },
    );

    try {
      left._run(
        runtime,
        ContObserver._(
          handleError,
          (a) {
            handleValue(_Left(a));
          },
        ),
      );
    } catch (error, st) {
      handleError(ThrownError.withStackTrace(error, st));
    }

    try {
      right._run(
        runtime,
        ContObserver._(
          handleError,
          (a2) {
            handleValue(_Right(a2));
          },
        ),
      );
    } catch (error, st) {
      handleError(ThrownError.withStackTrace(error, st));
    }
  });
}

Cont<E, F3, A> _eitherQuitFast<E, F1, F2, F3, A>(
  Cont<E, F1, A> left,
  Cont<E, F2, A> right,
  ContError<F3> Function(ContError<F1> f1, ContError<F2> f2)
      combine,
) {
  return Cont.fromRun((runtime0, observer) {
    final (runtime, handleValue, handleError) = _quitFast<E,
        ContError<F1>, ContError<F2>, ContError<F3>, A>(
      runtime0: runtime0,
      combine: combine,
      onPrimary: observer.onThen,
      onSecondary: observer.onElse,
      onPanic: (error, st) {
        observer.onElse(
          ThrownError.withStackTrace(error, st),
        );
      },
    );

    try {
      left._run(
        runtime,
        ContObserver._(
          (f1) {
            handleError(_Left(f1));
          },
          handleValue,
        ),
      );
    } catch (error, st) {
      handleError(
        _Left(ThrownError.withStackTrace(error, st)),
      );
    }

    try {
      right._run(
        runtime,
        ContObserver._(
          (f2) {
            handleError(_Right(f2));
          },
          handleValue,
        ),
      );
    } catch (error, st) {
      handleError(
        _Right(ThrownError.withStackTrace(error, st)),
      );
    }
  });
}

(
  ContRuntime<E> runtime,
  void Function(A a) handlePrimary,
  void Function(_Either<F1, F2> either) handleSecondary,
) _quitFast<E, F1, F2, F3, A>({
  required ContRuntime<E> runtime0,
  required F3 Function(F1 f1, F2 f2) combine,
  required void Function(A a) onPrimary,
  required void Function(F3 f3) onSecondary,
  required void Function(Object error, StackTrace st)
      onPanic,
}) {
  /*

  idle

  left secondary right null
  left null right secondary

   */

  final _QuitFastStateHolder<F1, F2> holder =
      _QuitFastStateHolder();

  final ContRuntime<E> runtime = ContRuntime._(
    runtime0.env(),
    () {
      return runtime0.isCancelled() || holder.state == null;
    },
    runtime0.onPanic,
  );

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
            break;
          case _QuitFastStep0<F1, F2>():
            holder.state =
                _QuitFastLeftSecondaryRightNull(f1);
          case _QuitFastLeftSecondaryRightNull<F1, F2>():
            break; // we can't have left secondary and get another left secondary - unreachable state
          case _QuitFastLeftNullRightSecondary<F1, F2>(
              f2: final f2
            ):
            final F3 f3;
            try {
              f3 = combine(f1, f2);
            } catch (error, st) {
              onPanic(error, st);
              return;
            }
            onSecondary(f3);
        }
      case _Right<F1, F2>(value: final f2):
        switch (holder.state) {
          case null:
            break;
          case _QuitFastStep0<F1, F2>():
            holder.state =
                _QuitFastLeftNullRightSecondary(f2);
          case _QuitFastLeftSecondaryRightNull<F1, F2>(
              f1: final f1
            ):
            final F3 f3;
            try {
              f3 = combine(f1, f2);
            } catch (error, st) {
              onPanic(error, st);
              return;
            }
            onSecondary(f3);
          case _QuitFastLeftNullRightSecondary<F1, F2>():
            break; // we can't have right secondary and get another right secondary - unreachable state
        }
    }
  }

  return (runtime, handlePrimary, handleSecondary);
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
