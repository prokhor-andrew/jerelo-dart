part of '../cont.dart';

Cont<E, A> _eitherMergeWhenAll<E, A>(
  Cont<E, A> left,
  Cont<E, A> right,
  A Function(A acc, A value) combine,
  //
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneSuccess = false;
    bool isOneTerminate = false;

    bool isLeftSucceededFirst = false;

    List<ContError>? outerLeft;
    List<ContError>? outerRight;

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
            ContError.withStackTrace(error, st),
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
          ContError.withStackTrace(error, st),
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
      outerLeft = [ContError.withStackTrace(error, st)];
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
      outerRight = [ContError.withStackTrace(error, st)];
      handleTerminate(false);
    }
  });
}

Cont<E, A> _eitherQuitFast<E, A>(
  Cont<E, A> left,
  Cont<E, A> right,
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneFailed = false;
    final List<ContError> resultErrors = [];
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

    ContObserver<A> makeObserver(
      void Function(List<ContError> errors)
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
          ContError.withStackTrace(error, st),
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
          ContError.withStackTrace(error, st),
        );
      });
    }
  });
}
