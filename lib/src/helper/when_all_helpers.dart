part of '../cont.dart';

Cont<E, F, A3> _bothWhenAll<E, F, A1, A2, A3>(
  Cont<E, F, A1> left,
  Cont<E, F, A2> right,
  A3 Function(A1 a1, A2 a2) combineValues,
  F Function(F, F) combineErrors,
  bool shouldFavorCrash,
) {
  // no absurdify, as they were absurdified before
  return Cont.fromRun((runtime, observer) {
    final (
      handleCrash,
      handlePrimary,
      handleSecondary,
    ) = _whenAll<E, F, F, F, A1, A2, A3>(
      runtime: runtime,
      onCrash: observer.onCrash,
      onPrimary: observer.onThen,
      onSecondary: (triple) {
        switch (triple) {
          case _Value1<F, F, F>(a: final f):
          case _Value2<F, F, F>(b: final f):
          case _Value3<F, F, F>(c: final f):
            observer.onElse(f);
        }
      },
      shouldFavorCrash: shouldFavorCrash,
      combinePrimary: combineValues,
      combineSecondary: combineErrors,
    );

    ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer.copyUpdate<F, A1>(
          onCrash: (crash) => handleCrash(_Left(crash)),
          onElse: (error) => handleSecondary(_Left(error)),
          onThen: (a) => handlePrimary(_Left(a)),
        ),
      );
    }).match((_) {}, observer.onCrash);

    ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer.copyUpdate<F, A2>(
          onCrash: (crash) => handleCrash(_Right(crash)),
          onElse: (error) => handleSecondary(_Right(error)),
          onThen: (a2) => handlePrimary(_Right(a2)),
        ),
      );
    }).match((_) {}, observer.onCrash);
  });
}

Cont<E, F3, A> _eitherWhenAll<E, F1, F2, F3, A>(
  Cont<E, F1, A> left,
  Cont<E, F2, A> right,
  F3 Function(F1 f1, F2 f2) combineErrors,
  A Function(A, A) combineValues,
  bool shouldFavorCrash,
) {
  return Cont.fromRun((runtime, observer) {
    final (
      handleCrash,
      handlePrimary,
      handleSecondary,
    ) = _whenAll<E, A, A, A, F1, F2, F3>(
      runtime: runtime,
      onCrash: observer.onCrash,
      onPrimary: observer.onElse,
      onSecondary: (triple) {
        switch (triple) {
          case _Value1<A, A, A>(a: final a):
          case _Value2<A, A, A>(b: final a):
          case _Value3<A, A, A>(c: final a):
            observer.onThen(a);
        }
      },
      shouldFavorCrash: shouldFavorCrash,
      combinePrimary: combineErrors,
      combineSecondary: combineValues,
    );

    ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer.copyUpdate<F1, A>(
          onCrash: (crash) => handleCrash(_Left(crash)),
          onElse: (error) => handlePrimary(_Left(error)),
          onThen: (a) => handleSecondary(_Left(a)),
        ),
      );
    }).match((_) {}, observer.onCrash);

    ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer.copyUpdate<F2, A>(
          onCrash: (crash) => handleCrash(_Right(crash)),
          onElse: (error) => handlePrimary(_Right(error)),
          onThen: (a2) => handleSecondary(_Right(a2)),
        ),
      );
    }).match((_) {}, observer.onCrash);
  });
}

Cont<E, F, A> _crashWhenAll<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right,
  A Function(A a1, A a2) combineValues,
  F Function(F f1, F f2) combineErrors,
  bool shouldFavorElse,
) {
  return Cont.fromRun((runtime, observer) {
    final _WhenAllStateHolder<A, A, F, F> holder =
        _WhenAllStateHolder();

    void handleThen(_Either<A, A> either) {
      if (runtime.isCancelled()) {
        return;
      }

      switch (holder.state) {
        case _Step0<A, A, F, F>():
          switch (either) {
            case _Left<A, A>(value: final a):
              holder.state = _Step1<A, A, F, F>(
                _Step1CaseLeftPrimaryRightNull(a),
              );
            case _Right<A, A>(value: final a):
              holder.state = _Step1<A, A, F, F>(
                _Step1CaseLeftNullRightPrimary(a),
              );
          }
        case _Step1<A, A, F, F>(_case: final aCase):
          switch (either) {
            case _Left<A, A>(value: final a1):
              switch (aCase) {
                case _Step1CaseLeftPrimaryRightNull<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftSecondaryRightNull<A, A,
                      F, F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightPrimary<A, A, F,
                      F>(
                    a2: final a2,
                  ):
                  // A, A -> A'
                  ContCrash.tryCatch(() {
                    observer.onThen(combineValues(a1, a2));
                  }).match((_) {}, observer.onCrash);
                case _Step1CaseLeftNullRightSecondary<A, A,
                      F, F>(f2: final f2):
                  // A, E -> ?
                  if (shouldFavorElse) {
                    observer.onElse(f2);
                  } else {
                    observer.onThen(a1);
                  }
                case _Step1CaseLeftCrashRightNull<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightCrash<A, A, F,
                      F>():
                  // A, C -> A
                  observer.onThen(a1);
              }
            case _Right<A, A>(value: final a2):
              switch (aCase) {
                case _Step1CaseLeftPrimaryRightNull<A, A, F,
                      F>(
                    a1: final a1,
                  ):
                  // A, A -> A'
                  ContCrash.tryCatch(() {
                    observer.onThen(combineValues(a1, a2));
                  }).match((_) {}, observer.onCrash);
                case _Step1CaseLeftSecondaryRightNull<A, A,
                      F, F>(f1: final f1):
                  // E, A -> ?
                  if (shouldFavorElse) {
                    observer.onElse(f1);
                  } else {
                    observer.onThen(a2);
                  }
                case _Step1CaseLeftNullRightPrimary<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightSecondary<A, A,
                      F, F>():
                  break; // unreachable
                case _Step1CaseLeftCrashRightNull<A, A, F,
                      F>():
                  // C, A -> A
                  observer.onThen(a2);
                case _Step1CaseLeftNullRightCrash<A, A, F,
                      F>():
                  break; // unreachable
              }
          }
      }
    }

    void handleElse(_Either<F, F> either) {
      if (runtime.isCancelled()) {
        return;
      }

      switch (holder.state) {
        case _Step0<A, A, F, F>():
          switch (either) {
            case _Left<F, F>(value: final f):
              holder.state = _Step1<A, A, F, F>(
                _Step1CaseLeftSecondaryRightNull(f),
              );
            case _Right<F, F>(value: final f):
              holder.state = _Step1<A, A, F, F>(
                _Step1CaseLeftNullRightSecondary(f),
              );
          }
        case _Step1<A, A, F, F>(_case: final aCase):
          switch (either) {
            case _Left<F, F>(value: final f1):
              switch (aCase) {
                case _Step1CaseLeftPrimaryRightNull<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftSecondaryRightNull<A, A,
                      F, F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightPrimary<A, A, F,
                      F>(
                    a2: final a2,
                  ):
                  // E, A -> ?
                  if (shouldFavorElse) {
                    observer.onElse(f1);
                  } else {
                    observer.onThen(a2);
                  }
                case _Step1CaseLeftNullRightSecondary<A, A,
                      F, F>(f2: final f2):
                  // E, E -> E'
                  ContCrash.tryCatch(() {
                    observer.onElse(combineErrors(f1, f2));
                  }).match((_) {}, observer.onCrash);
                case _Step1CaseLeftCrashRightNull<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightCrash<A, A, F,
                      F>():
                  // E, C -> E
                  observer.onElse(f1);
              }
            case _Right<F, F>(value: final f2):
              switch (aCase) {
                case _Step1CaseLeftPrimaryRightNull<A, A, F,
                      F>(
                    a1: final a1,
                  ):
                  // A, E -> ?
                  if (shouldFavorElse) {
                    observer.onElse(f2);
                  } else {
                    observer.onThen(a1);
                  }
                case _Step1CaseLeftSecondaryRightNull<A, A,
                      F, F>(f1: final f1):
                  // E, E -> E'
                  ContCrash.tryCatch(() {
                    observer.onElse(combineErrors(f1, f2));
                  }).match((_) {}, observer.onCrash);
                case _Step1CaseLeftNullRightPrimary<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightSecondary<A, A,
                      F, F>():
                  break; // unreachable
                case _Step1CaseLeftCrashRightNull<A, A, F,
                      F>():
                  // C, E -> E
                  observer.onElse(f2);
                case _Step1CaseLeftNullRightCrash<A, A, F,
                      F>():
                  break; // unreachable
              }
          }
      }
    }

    void handleCrash(_Either<ContCrash, ContCrash> either) {
      if (runtime.isCancelled()) {
        return;
      }

      switch (holder.state) {
        case _Step0<A, A, F, F>():
          switch (either) {
            case _Left<ContCrash, ContCrash>(
                value: final crash
              ):
              holder.state = _Step1<A, A, F, F>(
                _Step1CaseLeftCrashRightNull(crash),
              );
            case _Right<ContCrash, ContCrash>(
                value: final crash
              ):
              holder.state = _Step1<A, A, F, F>(
                _Step1CaseLeftNullRightCrash(crash),
              );
          }
        case _Step1<A, A, F, F>(_case: final aCase):
          switch (either) {
            case _Left<ContCrash, ContCrash>(
                value: final crash
              ):
              switch (aCase) {
                case _Step1CaseLeftPrimaryRightNull<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftSecondaryRightNull<A, A,
                      F, F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightPrimary<A, A, F,
                      F>(
                    a2: final a2,
                  ):
                  // C, A -> A
                  observer.onThen(a2);
                case _Step1CaseLeftNullRightSecondary<A, A,
                      F, F>(f2: final f2):
                  // C, E -> E
                  observer.onElse(f2);
                case _Step1CaseLeftCrashRightNull<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightCrash<A, A, F,
                      F>(
                    crash: final rightCrash,
                  ):
                  // C, C -> MC
                  observer.onCrash(
                      MergedCrash(crash, rightCrash));
              }
            case _Right<ContCrash, ContCrash>(
                value: final crash
              ):
              switch (aCase) {
                case _Step1CaseLeftPrimaryRightNull<A, A, F,
                      F>(
                    a1: final a1,
                  ):
                  // A, C -> A
                  observer.onThen(a1);
                case _Step1CaseLeftSecondaryRightNull<A, A,
                      F, F>(f1: final f1):
                  // E, C -> E
                  observer.onElse(f1);
                case _Step1CaseLeftNullRightPrimary<A, A, F,
                      F>():
                  break; // unreachable
                case _Step1CaseLeftNullRightSecondary<A, A,
                      F, F>():
                  break; // unreachable
                case _Step1CaseLeftCrashRightNull<A, A, F,
                      F>(
                    crash: final leftCrash,
                  ):
                  // C, C -> MC
                  observer.onCrash(
                      MergedCrash(leftCrash, crash));
                case _Step1CaseLeftNullRightCrash<A, A, F,
                      F>():
                  break; // unreachable
              }
          }
      }
    }

    ContCrash.tryCatch(() {
      left.runWith(
        runtime,
        observer.copyUpdate<F, A>(
          onCrash: (crash) => handleCrash(_Left(crash)),
          onElse: (error) => handleElse(_Left(error)),
          onThen: (a) => handleThen(_Left(a)),
        ),
      );
    }).match((_) {}, (crash) {
      handleCrash(_Left(crash));
    });

    ContCrash.tryCatch(() {
      right.runWith(
        runtime,
        observer.copyUpdate<F, A>(
          onCrash: (crash) => handleCrash(_Right(crash)),
          onElse: (error) => handleElse(_Right(error)),
          onThen: (a) => handleThen(_Right(a)),
        ),
      );
    }).match((_) {}, (crash) {
      handleCrash(_Right(crash));
    });
  });
}

final class _WhenAllStateHolder<A1, A2, F1, F2> {
  _Step<A1, A2, F1, F2> state = const _Step0();

  _WhenAllStateHolder();
}

(
  void Function(
    _Either<ContCrash, ContCrash> either,
  ) handleCrash,
  void Function(_Either<A1, A2> either) handlePrimary,
  void Function(_Either<F1, F2> either) handleSecondary,
) _whenAll<E, F1, F2, F3, A1, A2, A3>({
  required ContRuntime<E> runtime,
  required A3 Function(
    A1 a,
    A2 a2,
  ) combinePrimary,
  required F3 Function(
    F1 f1,
    F2 f2,
  ) combineSecondary,
  required void Function(A3 a3) onPrimary,
  required void Function(_Triple<F1, F2, F3>) onSecondary,
  required void Function(ContCrash crash) onCrash,
  required bool shouldFavorCrash,
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
      case _Step0<A1, A2, F1, F2>():
        switch (either) {
          case _Left<A1, A2>(value: final a1):
            holder.state = _Step1<A1, A2, F1, F2>(
              _Step1CaseLeftPrimaryRightNull(
                a1,
              ),
            );
          case _Right<A1, A2>(value: final a2):
            holder.state = _Step1<A1, A2, F1, F2>(
              _Step1CaseLeftNullRightPrimary(
                a2,
              ),
            );
        }
      case _Step1<A1, A2, F1, F2>(_case: final aCase):
        switch (either) {
          case _Left<A1, A2>(value: final a1):
            switch (aCase) {
              case _Step1CaseLeftPrimaryRightNull<A1, A2,
                    F1, F2>():
                break; // we can't get left value when we already have left value - unreachable state
              case _Step1CaseLeftSecondaryRightNull<A1, A2,
                    F1, F2>():
                break; // we can't get left value when we already have left error - unreachable state
              case _Step1CaseLeftNullRightPrimary<A1, A2,
                    F1, F2>(
                  a2: final a2,
                ):
                ContCrash.tryCatch(() {
                  final A3 a3 = combinePrimary(a1, a2);
                  onPrimary(a3);
                }).match((_) {}, onCrash);
              case _Step1CaseLeftNullRightSecondary<A1, A2,
                    F1, F2>(f2: final f2):
                onSecondary(_Value2(f2));
              case _Step1CaseLeftCrashRightNull<A1, A2, F1,
                    F2>():
                break; // we can't get left value when we already have left crash - unreachable state
              case _Step1CaseLeftNullRightCrash<A1, A2, F1,
                    F2>(crash: final crash):
                onCrash(crash);
            }
          case _Right<A1, A2>(value: final a2):
            switch (aCase) {
              case _Step1CaseLeftPrimaryRightNull<A1, A2,
                    F1, F2>(
                  a1: final a1,
                ):
                ContCrash.tryCatch(() {
                  final A3 a3 = combinePrimary(a1, a2);
                  onPrimary(a3);
                }).match((_) {}, onCrash);

              case _Step1CaseLeftSecondaryRightNull<A1, A2,
                    F1, F2>(f1: final f1):
                onSecondary(_Value1(f1));
              case _Step1CaseLeftNullRightPrimary<A1, A2,
                    F1, F2>():
                break; // we can't get right value when we already have right value - unreachable state
              case _Step1CaseLeftNullRightSecondary<A1, A2,
                    F1, F2>():
                break; // we can't get right value when we already have right error - unreachable state
              case _Step1CaseLeftCrashRightNull<A1, A2, F1,
                    F2>(crash: final crash):
                onCrash(crash);
              case _Step1CaseLeftNullRightCrash<A1, A2, F1,
                    F2>():
                break; // we can't get right value when we already have right crash - unreachable state
            }
        }
    }
  }

  void handleSecondary(_Either<F1, F2> either) {
    if (runtime.isCancelled()) {
      return;
    }

    switch (holder.state) {
      case _Step0<A1, A2, F1, F2>():
        switch (either) {
          case _Left<F1, F2>(value: final f1):
            holder.state = _Step1<A1, A2, F1, F2>(
              _Step1CaseLeftSecondaryRightNull(
                f1,
              ),
            );
          case _Right<F1, F2>(value: final f2):
            holder.state = _Step1<A1, A2, F1, F2>(
              _Step1CaseLeftNullRightSecondary(
                f2,
              ),
            );
        }
      case _Step1<A1, A2, F1, F2>(_case: final aCase):
        switch (either) {
          case _Left<F1, F2>(value: final f1):
            switch (aCase) {
              case _Step1CaseLeftPrimaryRightNull<A1, A2,
                    F1, F2>():
                break; // we can't get left error when we already have left value - unreachable state
              case _Step1CaseLeftSecondaryRightNull<A1, A2,
                    F1, F2>():
                break; // we can't get left error when we already have left error - unreachable state
              case _Step1CaseLeftNullRightPrimary<A1, A2,
                    F1, F2>():
                onSecondary(_Value1(f1));
              case _Step1CaseLeftNullRightSecondary<A1, A2,
                    F1, F2>(f2: final f2):
                ContCrash.tryCatch(() {
                  final F3 f3 = combineSecondary(f1, f2);
                  onSecondary(_Value3(f3));
                }).match((_) {}, onCrash);
              case _Step1CaseLeftCrashRightNull<A1, A2, F1,
                    F2>():
                break; // we can't get left error when we already have left crash - unreachable state
              case _Step1CaseLeftNullRightCrash<A1, A2, F1,
                    F2>(crash: final crash):
                if (shouldFavorCrash) {
                  onCrash(crash);
                } else {
                  onSecondary(_Value1(f1));
                }
            }
          case _Right<F1, F2>(value: final f2):
            switch (aCase) {
              case _Step1CaseLeftPrimaryRightNull<A1, A2,
                    F1, F2>():
                onSecondary(_Value2(f2));
              case _Step1CaseLeftSecondaryRightNull<A1, A2,
                    F1, F2>(f1: final f1):
                ContCrash.tryCatch(() {
                  final F3 f3 = combineSecondary(f1, f2);
                  onSecondary(_Value3(f3));
                }).match((_) {}, onCrash);
              case _Step1CaseLeftNullRightPrimary<A1, A2,
                    F1, F2>():
                break; // we can't get right error when we already have right value - unreachable state
              case _Step1CaseLeftNullRightSecondary<A1, A2,
                    F1, F2>():
                break; // we can't get right error when we already have right error - unreachable state
              case _Step1CaseLeftCrashRightNull<A1, A2, F1,
                    F2>(crash: final crash):
                if (shouldFavorCrash) {
                  onCrash(crash);
                } else {
                  onSecondary(_Value2(f2));
                }
              case _Step1CaseLeftNullRightCrash<A1, A2, F1,
                    F2>():
                break; // we can't get right error when we already have right crash - unreachable state
            }
        }
    }
  }

  void handleCrash(_Either<ContCrash, ContCrash> either) {
    if (runtime.isCancelled()) {
      return;
    }

    switch (holder.state) {
      case _Step0<A1, A2, F1, F2>():
        switch (either) {
          case _Left<ContCrash, ContCrash>(
              value: final crash
            ):
            holder.state = _Step1<A1, A2, F1, F2>(
              _Step1CaseLeftCrashRightNull(crash),
            );
          case _Right<ContCrash, ContCrash>(
              value: final crash
            ):
            holder.state = _Step1<A1, A2, F1, F2>(
              _Step1CaseLeftNullRightCrash(crash),
            );
        }
      case _Step1<A1, A2, F1, F2>(_case: final aCase):
        switch (either) {
          case _Left<ContCrash, ContCrash>(
              value: final crash
            ):
            switch (aCase) {
              case _Step1CaseLeftPrimaryRightNull<A1, A2,
                    F1, F2>():
                break; // we can't get left crash when we already have left value - unreachable state
              case _Step1CaseLeftSecondaryRightNull<A1, A2,
                    F1, F2>():
                break; // we can't get left crash when we already have left error - unreachable state
              case _Step1CaseLeftNullRightPrimary<A1, A2,
                    F1, F2>():
                onCrash(crash);
              case _Step1CaseLeftNullRightSecondary<A1, A2,
                    F1, F2>(f2: final f2):
                if (shouldFavorCrash) {
                  onCrash(crash);
                } else {
                  onSecondary(_Value2(f2));
                }
              case _Step1CaseLeftCrashRightNull<A1, A2, F1,
                    F2>():
                break; // we can't get left crash when we already have left crash - unreachable state
              case _Step1CaseLeftNullRightCrash<A1, A2, F1,
                    F2>(crash: final rightCrash):
                onCrash(MergedCrash(crash, rightCrash));
            }
          case _Right<ContCrash, ContCrash>(
              value: final crash
            ):
            switch (aCase) {
              case _Step1CaseLeftPrimaryRightNull<A1, A2,
                    F1, F2>():
                onCrash(crash);
              case _Step1CaseLeftSecondaryRightNull<A1, A2,
                    F1, F2>(f1: final f1):
                if (shouldFavorCrash) {
                  onCrash(crash);
                } else {
                  onSecondary(_Value1(f1));
                }
              case _Step1CaseLeftNullRightPrimary<A1, A2,
                    F1, F2>():
                break; // we can't get right crash when we already have right value - unreachable state
              case _Step1CaseLeftNullRightSecondary<A1, A2,
                    F1, F2>():
                break; // we can't get right crash when we already have right error - unreachable state
              case _Step1CaseLeftCrashRightNull<A1, A2, F1,
                    F2>(crash: final leftCrash):
                onCrash(MergedCrash(leftCrash, crash));
              case _Step1CaseLeftNullRightCrash<A1, A2, F1,
                    F2>():
                break; // we can't get right crash when we already have right crash - unreachable state
            }
        }
    }
  }

  return (handleCrash, handlePrimary, handleSecondary);
}

sealed class _Step<A1, A2, F1, F2> {
  const _Step();
}

final class _Step0<A1, A2, F1, F2>
    extends _Step<A1, A2, F1, F2> {
  const _Step0();
}

final class _Step1<A1, A2, F1, F2>
    extends _Step<A1, A2, F1, F2> {
  final _Step1Case<A1, A2, F1, F2> _case;

  const _Step1(this._case);
}

sealed class _Step1Case<A1, A2, F1, F2> {
  const _Step1Case();
}

final class _Step1CaseLeftPrimaryRightNull<A1, A2, F1, F2>
    extends _Step1Case<A1, A2, F1, F2> {
  final A1 a1;

  const _Step1CaseLeftPrimaryRightNull(this.a1);
}

final class _Step1CaseLeftSecondaryRightNull<A1, A2, F1, F2>
    extends _Step1Case<A1, A2, F1, F2> {
  final F1 f1;

  const _Step1CaseLeftSecondaryRightNull(this.f1);
}

final class _Step1CaseLeftCrashRightNull<A1, A2, F1, F2>
    extends _Step1Case<A1, A2, F1, F2> {
  final ContCrash crash;

  const _Step1CaseLeftCrashRightNull(this.crash);
}

final class _Step1CaseLeftNullRightPrimary<A1, A2, F1, F2>
    extends _Step1Case<A1, A2, F1, F2> {
  final A2 a2;

  const _Step1CaseLeftNullRightPrimary(this.a2);
}

final class _Step1CaseLeftNullRightSecondary<A1, A2, F1, F2>
    extends _Step1Case<A1, A2, F1, F2> {
  final F2 f2;

  const _Step1CaseLeftNullRightSecondary(this.f2);
}

final class _Step1CaseLeftNullRightCrash<A1, A2, F1, F2>
    extends _Step1Case<A1, A2, F1, F2> {
  final ContCrash crash;

  const _Step1CaseLeftNullRightCrash(this.crash);
}
