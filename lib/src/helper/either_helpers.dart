part of '../cont.dart';

/// Implementation of `either` with the merge-when-all policy.
///
/// Runs [left] and [right] in parallel and waits for both to complete.
/// If one succeeds and the other terminates, the successful value is returned.
/// If both succeed, their values are merged using [combine] (first-succeeded
/// value is passed as the accumulator). If both terminate, their errors are
/// concatenated.
Cont<E, F, A> _eitherMergeWhenAll<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right,
  A Function(A acc, A value) combine,
  //
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneSuccess = false;
    bool isOneTerminate = false;

    bool isLeftSucceededFirst = false;

    List<ContError<F>>? outerLeft;
    List<ContError<F>>? outerRight;

    A? leftVal;
    A? rightVal;

    void handleValue(bool isLeft, A value) {
      if (isOneTerminate) {
        if (isLeft) {
          leftVal = value;
          observer.onThen(value);
        } else {
          rightVal = value;
          observer.onThen(value);
        }

        return;
      }

      if (isOneSuccess) {
        // check the policy and decide what to do with both error lists
        if (isLeft) {
          leftVal = value;
        } else {
          rightVal = value;
        }

        final A firstValue;
        final A secondValue;

        if (isLeftSucceededFirst) {
          firstValue = leftVal as A;
          secondValue = rightVal as A;
        } else {
          firstValue = rightVal as A;
          secondValue = leftVal as A;
        }

        try {
          observer.onThen(combine(firstValue, secondValue));
        } catch (error, st) {
          observer.onElse([
            ThrownError(error, st),
          ]);
        }
        return;
      }

      isOneSuccess = true;
      if (isLeft) {
        isLeftSucceededFirst = true;
        leftVal = value;
      } else {
        isLeftSucceededFirst = false;
        rightVal = value;
      }
    }

    void handleTerminate(bool isLeft) {
      if (isOneSuccess) {
        if (isLeft) {
          observer.onThen(rightVal as A);
        } else {
          observer.onThen(leftVal as A);
        }
        return;
      }

      if (!isOneTerminate) {
        isOneTerminate = true;
        return;
      }

      try {
        final result = outerLeft! + outerRight!;
        observer.onElse(result);
      } catch (error, st) {
        observer.onElse([
          ThrownError(error, st),
        ]);
      }
    }

    try {
      left._run(
        runtime,
        ContObserver._(
          (errors) {
            if (runtime.isCancelled()) {
              return;
            }
            // strict order must be followed
            outerLeft = [...errors];
            handleTerminate(true);
          },
          (a1) {
            if (runtime.isCancelled()) {
              return;
            }
            handleValue(true, a1);
          },
        ),
      );
    } catch (error, st) {
      outerLeft = [ThrownError(error, st)];
      handleTerminate(true);
    }

    try {
      right._run(
        runtime,
        ContObserver._(
          (errors) {
            if (runtime.isCancelled()) {
              return;
            }
            // strict order must be followed
            outerRight = [...errors];
            handleTerminate(false);
          },
          (a2) {
            if (runtime.isCancelled()) {
              return;
            }
            handleValue(false, a2);
          },
        ),
      );
    } catch (error, st) {
      outerRight = [ThrownError(error, st)];
      handleTerminate(false);
    }
  });
}

/// Implementation of `either` with the quit-fast policy.
///
/// Runs [left] and [right] in parallel with a shared runtime that reports
/// cancellation as soon as one side succeeds. If either succeeds first, the
/// other is effectively cancelled and the value is returned. If both
/// terminate, their errors are concatenated.
Cont<E, F, A> _eitherQuitFast<E, F, A>(
  Cont<E, F, A> left,
  Cont<E, F, A> right,
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneFailed = false;
    final List<ContError<F>> resultErrors = [];
    bool isDone = false;

    final ContRuntime<E> sharedContRuntime = ContRuntime._(
      runtime.env(),
      () {
        return runtime.isCancelled() || isDone;
      },
      runtime.onPanic,
    );

    void handleTerminate(
      void Function() codeToUpdateState,
    ) {
      if (isOneFailed) {
        codeToUpdateState();

        observer.onElse(resultErrors);
        return;
      }
      isOneFailed = true;

      codeToUpdateState();
    }

    ContObserver<F, A> makeObserver(
      void Function(List<ContError<F>> errors)
          codeToUpdateState,
    ) {
      return ContObserver._(
        (errors) {
          if (sharedContRuntime.isCancelled()) {
            return;
          }

          handleTerminate(() {
            codeToUpdateState([...errors]);
          });
        },
        (a) {
          if (sharedContRuntime.isCancelled()) {
            return;
          }

          isDone = true;
          observer.onThen(a);
        },
      );
    }

    try {
      left._run(
        sharedContRuntime,
        makeObserver((errors) {
          resultErrors.insertAll(0, errors);
        }),
      );
    } catch (error, st) {
      handleTerminate(() {
        resultErrors.insert(
          0,
          ThrownError(error, st),
        );
      });
    }

    try {
      right._run(
        sharedContRuntime,
        makeObserver((errors) {
          resultErrors.addAll(errors);
        }),
      );
    } catch (error, st) {
      handleTerminate(() {
        resultErrors.add(
          ThrownError(error, st),
        );
      });
    }
  });
}
