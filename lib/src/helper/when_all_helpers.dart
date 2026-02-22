part of '../cont.dart';

Cont<E, F, A3> _bothWhenAll<E, F, A1, A2, A3>(
  Cont<E, F, A1> left,
  Cont<E, F, A2> right,
  A3 Function(A1 a1, A2 a2) combineValues,
  F Function(F, F) combineErrors,
) {
  return Cont.fromRun((runtime, observer) {
    final (handlePrimary, handleSecondary) =
        _whenAll<E, F, F, F, A1, A2, A3>(
      runtime: runtime,
      onPrimary: observer.onThen,
      onSecondary: (triple) {
        switch (triple) {
          case _Value1<F, F, F>(a: final f):
          case _Value2<F, F, F>(b: final f):
          case _Value3<F, F, F>(c: final f):
            observer.onElse(f);
        }
      },
      combinePrimary: combineValues,
      combineSecondary: combineErrors,
      onPanic: (error, st) {
        observer.onCrash(NormalCrash._(error, st));
      },
    );

    try {
      left._run(
        runtime,
        observer.copyUpdateOnElse<F>((error) {
          handleSecondary(_Left(error));
        }).copyUpdateOnThen<A1>((a) {
          handlePrimary(_Left(a));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }

    try {
      right._run(
        runtime,
        observer.copyUpdateOnElse<F>((error) {
          handleSecondary(_Right(error));
        }).copyUpdateOnThen<A2>((a2) {
          handlePrimary(_Right(a2));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }
  });
}

Cont<E, F3, A> _eitherWhenAll<E, F1, F2, F3, A>(
  Cont<E, F1, A> left,
  Cont<E, F2, A> right,
  F3 Function(F1 f1, F2 f2) combineErrors,
  A Function(A, A) combineValues,
) {
  return Cont.fromRun((runtime, observer) {
    final (handlePrimary, handleSecondary) =
        _whenAll<E, A, A, A, F1, F2, F3>(
      runtime: runtime,
      onPrimary: observer.onElse,
      onSecondary: (triple) {
        switch (triple) {
          case _Value1<A, A, A>(a: final a):
          case _Value2<A, A, A>(b: final a):
          case _Value3<A, A, A>(c: final a):
            observer.onThen(a);
        }
      },
      combinePrimary: combineErrors,
      combineSecondary: combineValues,
      onPanic: (error, st) {
        observer.onCrash(NormalCrash._(error, st));
      },
    );

    try {
      left._run(
        runtime,
        observer.copyUpdateOnElse<F1>((error) {
          handlePrimary(_Left(error));
        }).copyUpdateOnThen<A>((a) {
          handleSecondary(_Left(a));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }

    try {
      right._run(
        runtime,
        observer.copyUpdateOnElse<F2>((error) {
          handlePrimary(_Right(error));
        }).copyUpdateOnThen<A>((a2) {
          handleSecondary(_Right(a2));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }
  });
}

Cont<E, F, A> _bothWhenAllCrash<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right,
  A Function(A a1, A a2) combineValues,
  F Function(F f1, F f2) combineErrors,
) {
  return Cont.fromRun((runtime, observer) {
    final (handlePrimary, handleSecondary) =
        _whenAll<E, F, F, F, A, A, A>(
      runtime: runtime,
      onPrimary: observer.onThen,
      onSecondary: (triple) {
        switch (triple) {
          case _Value1<F, F, F>(a: final f):
          case _Value2<F, F, F>(b: final f):
          case _Value3<F, F, F>(c: final f):
            observer.onElse(f);
        }
      },
      combinePrimary: combineValues,
      combineSecondary: combineErrors,
      onPanic: (error, st) {
        observer.onCrash(NormalCrash._(error, st));
      },
    );

    try {
      left._run(
        runtime,
        observer.copyUpdateOnElse<F>((error) {
          handleSecondary(_Left(error));
        }).copyUpdateOnThen<A>((a) {
          handlePrimary(_Left(a));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }

    try {
      right._run(
        runtime,
        observer.copyUpdateOnElse<F>((error) {
          handleSecondary(_Right(error));
        }).copyUpdateOnThen<A>((a) {
          handlePrimary(_Right(a));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }
  });
}

Cont<E, F, A> _eitherWhenAllCrash<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right,
  F Function(F f1, F f2) combineErrors,
  A Function(A a1, A a2) combineValues,
) {
  return Cont.fromRun((runtime, observer) {
    final (handlePrimary, handleSecondary) =
        _whenAll<E, A, A, A, F, F, F>(
      runtime: runtime,
      onPrimary: observer.onElse,
      onSecondary: (triple) {
        switch (triple) {
          case _Value1<A, A, A>(a: final a):
          case _Value2<A, A, A>(b: final a):
          case _Value3<A, A, A>(c: final a):
            observer.onThen(a);
        }
      },
      combinePrimary: combineErrors,
      combineSecondary: combineValues,
      onPanic: (error, st) {
        observer.onCrash(NormalCrash._(error, st));
      },
    );

    try {
      left._run(
        runtime,
        observer.copyUpdateOnElse<F>((error) {
          handlePrimary(_Left(error));
        }).copyUpdateOnThen<A>((a) {
          handleSecondary(_Left(a));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }

    try {
      right._run(
        runtime,
        observer.copyUpdateOnElse<F>((error) {
          handlePrimary(_Right(error));
        }).copyUpdateOnThen<A>((a2) {
          handleSecondary(_Right(a2));
        }),
      );
    } catch (error, st) {
      observer.onCrash(NormalCrash._(error, st));
    }
  });
}

final class _WhenAllStateHolder<A1, A2, F1, F2> {
  _WhenAllStep<A1, A2, F1, F2> state =
      const _WhenAllStep0();

  _WhenAllStateHolder();
}

(
  void Function(_Either<A1, A2> either) handlePrimary,
  void Function(_Either<F1, F2> either) handleSecondary,
) _whenAll<E, F1, F2, F3, A1, A2, A3>({
  required ContRuntime<E> runtime,
  required A3 Function(A1 a, A2 a2) combinePrimary,
  required F3 Function(
    F1 f1,
    F2 f2,
  ) combineSecondary,
  required void Function(A3 a3) onPrimary,
  required void Function(_Triple<F1, F2, F3>) onSecondary,
  required void Function(Object error, StackTrace st)
      onPanic,
}) {
  /*
    states:
    - idle

    - left secondary + right null
    - left primary + right null
    - left null + right secondary
    - left null + right primary

    // these states we don't set, we just emit proper output
    - left secondary + right primary
    - left primary + right secondary
    - left secondary + right secondary
    - left primary + right primary

     */

  final _WhenAllStateHolder<A1, A2, F1, F2> holder =
      _WhenAllStateHolder();

  void handlePrimary(_Either<A1, A2> either) {
    if (runtime.isCancelled()) {
      return;
    }

    switch (holder.state) {
      case _WhenAllStep0<A1, A2, F1, F2>():
        switch (either) {
          case _Left<A1, A2>(value: final a1):
            holder.state = _WhenAllStep1<A1, A2, F1, F2>(
              _WhenAllStep1CaseLeftPrimaryRightNull(
                a1,
              ),
            );
          case _Right<A1, A2>(value: final a2):
            holder.state = _WhenAllStep1<A1, A2, F1, F2>(
              _WhenAllStep1CaseLeftNullRightPrimary(
                a2,
              ),
            );
        }
      case _WhenAllStep1<A1, A2, F1, F2>(
          _case: final aCase
        ):
        switch (either) {
          case _Left<A1, A2>(value: final a1):
            switch (aCase) {
              case _WhenAllStep1CaseLeftPrimaryRightNull<A1,
                    A2, F1, F2>():
                break; // we can't get left value when we already have left value - unreachable state
              case _WhenAllStep1CaseLeftSecondaryRightNull<
                    A1, A2, F1, F2>():
                break; // we can't get left value when we already have left error - unreachable state
              case _WhenAllStep1CaseLeftNullRightPrimary<A1,
                    A2, F1, F2>(a2: final a2):
                final A3 a3;
                try {
                  a3 = combinePrimary(a1, a2);
                } catch (error, st) {
                  onPanic(error, st);
                  return;
                }
                onPrimary(a3);
              case _WhenAllStep1CaseLeftNullRightSecondary<
                    A1, A2, F1, F2>(f2: final f2):
                onSecondary(_Value2(f2));
            }
          case _Right<A1, A2>(value: final a2):
            switch (aCase) {
              case _WhenAllStep1CaseLeftPrimaryRightNull<A1,
                    A2, F1, F2>(a1: final a1):
                final A3 a3;
                try {
                  a3 = combinePrimary(a1, a2);
                } catch (error, st) {
                  onPanic(error, st);
                  return;
                }
                onPrimary(a3);
              case _WhenAllStep1CaseLeftSecondaryRightNull<
                    A1, A2, F1, F2>(f1: final f1):
                onSecondary(_Value1(f1));
              case _WhenAllStep1CaseLeftNullRightPrimary<A1,
                    A2, F1, F2>():
                break; // we can't get right value when we already have right value - unreachable state
              case _WhenAllStep1CaseLeftNullRightSecondary<
                    A1, A2, F1, F2>():
                break; // we can't get right value when we already have right error - unreachable state
            }
        }
    }
  }

  void handleSecondary(_Either<F1, F2> either) {
    if (runtime.isCancelled()) {
      return;
    }

    switch (holder.state) {
      case _WhenAllStep0<A1, A2, F1, F2>():
        switch (either) {
          case _Left<F1, F2>(value: final f1):
            holder.state = _WhenAllStep1<A1, A2, F1, F2>(
              _WhenAllStep1CaseLeftSecondaryRightNull(
                f1,
              ),
            );
          case _Right<F1, F2>(value: final f2):
            holder.state = _WhenAllStep1<A1, A2, F1, F2>(
              _WhenAllStep1CaseLeftNullRightSecondary(
                f2,
              ),
            );
        }
      case _WhenAllStep1<A1, A2, F1, F2>(
          _case: final aCase
        ):
        switch (either) {
          case _Left<F1, F2>(value: final f1):
            switch (aCase) {
              case _WhenAllStep1CaseLeftPrimaryRightNull<A1,
                    A2, F1, F2>():
                break; // we can't get left error when we already have left value - unreachable state
              case _WhenAllStep1CaseLeftSecondaryRightNull<
                    A1, A2, F1, F2>():
                break; // we can't get left error when we already have left error - unreachable state
              case _WhenAllStep1CaseLeftNullRightPrimary<A1,
                    A2, F1, F2>():
                onSecondary(_Value1(f1));
              case _WhenAllStep1CaseLeftNullRightSecondary<
                    A1, A2, F1, F2>(f2: final f2):
                final F3 f3;
                try {
                  f3 = combineSecondary(f1, f2);
                } catch (error, st) {
                  onPanic(error, st);
                  return;
                }
                onSecondary(_Value3(f3));
            }
          case _Right<F1, F2>(value: final f2):
            switch (aCase) {
              case _WhenAllStep1CaseLeftPrimaryRightNull<A1,
                    A2, F1, F2>():
                onSecondary(_Value2(f2));
              case _WhenAllStep1CaseLeftSecondaryRightNull<
                    A1, A2, F1, F2>(f1: final f1):
                final F3 f3;
                try {
                  f3 = combineSecondary(f1, f2);
                } catch (error, st) {
                  onPanic(error, st);
                  return;
                }
                onSecondary(_Value3(f3));
              case _WhenAllStep1CaseLeftNullRightPrimary<A1,
                    A2, F1, F2>():
                break; // we can't get right error when we already have right value - unreachable state
              case _WhenAllStep1CaseLeftNullRightSecondary<
                    A1, A2, F1, F2>():
                break; // we can't get right error when we already have right error - unreachable state
            }
        }
    }
  }

  return (handlePrimary, handleSecondary);
}

sealed class _WhenAllStep<A1, A2, F1, F2> {
  const _WhenAllStep();
}

final class _WhenAllStep0<A1, A2, F1, F2>
    extends _WhenAllStep<A1, A2, F1, F2> {
  const _WhenAllStep0();
}

final class _WhenAllStep1<A1, A2, F1, F2>
    extends _WhenAllStep<A1, A2, F1, F2> {
  final _WhenAllStep1Case<A1, A2, F1, F2> _case;

  const _WhenAllStep1(this._case);
}

sealed class _WhenAllStep1Case<A1, A2, F1, F2> {
  const _WhenAllStep1Case();
}

final class _WhenAllStep1CaseLeftPrimaryRightNull<A1, A2,
    F1, F2> extends _WhenAllStep1Case<A1, A2, F1, F2> {
  final A1 a1;

  const _WhenAllStep1CaseLeftPrimaryRightNull(
    this.a1,
  );
}

final class _WhenAllStep1CaseLeftSecondaryRightNull<A1, A2,
    F1, F2> extends _WhenAllStep1Case<A1, A2, F1, F2> {
  final F1 f1;

  const _WhenAllStep1CaseLeftSecondaryRightNull(
    this.f1,
  );
}

final class _WhenAllStep1CaseLeftNullRightPrimary<A1, A2,
    F1, F2> extends _WhenAllStep1Case<A1, A2, F1, F2> {
  final A2 a2;

  const _WhenAllStep1CaseLeftNullRightPrimary(
    this.a2,
  );
}

final class _WhenAllStep1CaseLeftNullRightSecondary<A1, A2,
    F1, F2> extends _WhenAllStep1Case<A1, A2, F1, F2> {
  final F2 f2;

  const _WhenAllStep1CaseLeftNullRightSecondary(
    this.f2,
  );
}
