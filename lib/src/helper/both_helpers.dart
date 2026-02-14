part of '../cont.dart';

/// Implementation of `both` with the merge-when-all policy.
///
/// Runs [left] and [right] in parallel and waits for both to complete.
/// If both succeed, their values are combined using [combine]. If either
/// or both terminate, errors are merged (preserving the order of the
/// first failure) and propagated as a single termination.
Cont<E, A3> _bothMergeWhenAll<E, A1, A2, A3>(
  Cont<E, A1> left,
  Cont<E, A2> right,
  A3 Function(A1 a, A2 a2) combine,
  //
) {
  return Cont.fromRun((runtime, observer) {
    bool isOneFailed = false;
    bool isOneValue = false;

    bool isLeftFailedFirst = false;

    A1? outerA1;
    A2? outerA2;

    final List<ContError> leftErrors = [];
    final List<ContError> rightErrors = [];

    void handleValue(_Either<A1, A2> either) {
      if (runtime.isCancelled()) {
        return;
      }

      switch (either) {
        case _Left<A1, A2>(value: final a1):
          outerA1 = a1;
        case _Right<A1, A2>(value: final a2):
          outerA2 = a2;
      }

      if (isOneFailed) {
        observer.onElse(leftErrors + rightErrors);
        return;
      }

      if (!isOneValue) {
        isOneValue = true;
        return;
      }

      try {
        final c = combine(outerA1 as A1, outerA2 as A2);
        observer.onThen(c);
      } catch (error, st) {
        observer.onElse([
          ContError.withStackTrace(error, st),
        ]);
      }
    }

    void handleTerminate(
      bool isLeft,
      List<ContError> errors,
    ) {
      if (runtime.isCancelled()) {
        return;
      }

      if (isOneValue) {
        if (isLeft) {
          leftErrors.addAll(errors);
        } else {
          rightErrors.addAll(errors);
        }

        observer.onElse(leftErrors + rightErrors);
        return;
      }

      if (isOneFailed) {
        // check the policy and decide what to do with both error lists
        if (isLeft) {
          leftErrors.addAll(errors);
        } else {
          rightErrors.addAll(errors);
        }

        final List<ContError> firstErrors;
        final List<ContError> secondErrors;

        if (isLeftFailedFirst) {
          firstErrors = leftErrors;
          secondErrors = rightErrors;
        } else {
          firstErrors = rightErrors;
          secondErrors = leftErrors;
        }

        observer.onElse(firstErrors + secondErrors);
        return;
      }

      isOneFailed = true;
      if (isLeft) {
        isLeftFailedFirst = true;
        leftErrors.addAll(errors);
      } else {
        isLeftFailedFirst = false;
        rightErrors.addAll(errors);
      }
    }

    try {
      left._run(
        runtime,
        ContObserver._(
          (errors) {
            handleTerminate(true, [...errors]);
          },
          (a) {
            handleValue(_Left(a));
          },
        ),
      );
    } catch (error, st) {
      handleTerminate(true, [
        ContError.withStackTrace(error, st),
      ]);
    }

    try {
      right._run(
        runtime,
        ContObserver._(
          (errors) {
            handleTerminate(false, [...errors]);
          },
          (a2) {
            handleValue(_Right(a2));
          },
        ),
      );
    } catch (error, st) {
      handleTerminate(false, [
        ContError.withStackTrace(error, st),
      ]);
    }
  });
}

/// Implementation of `both` with the quit-fast policy.
///
/// Runs [left] and [right] in parallel with a shared runtime that reports
/// cancellation as soon as either side terminates. If both succeed, their
/// values are combined using [combine]. If either terminates first, the
/// other is effectively cancelled and the errors are propagated immediately.
Cont<E, A3> _bothQuitFast<E, A1, A2, A3>(
  Cont<E, A1> left,
  Cont<E, A2> right,
  A3 Function(A1 a1, A2 a2) combine,
) {
  return Cont.fromRun((runtime, observer) {
    bool isDone = false;
    bool isOneValue = false;

    A1? outerA1;
    A2? outerA2;
    final List<ContError> resultErrors = [];

    final ContRuntime<E> sharedContRuntime = ContRuntime._(
      runtime.env(),
      () {
        return runtime.isCancelled() || isDone;
      },
      runtime.onPanic,
    );

    void handleValue() {
      if (!isOneValue) {
        isOneValue = true;
        return;
      }

      isDone = true;
      try {
        final c = combine(outerA1 as A1, outerA2 as A2);
        observer.onThen(c);
      } catch (error, st) {
        observer.onElse([
          ContError.withStackTrace(error, st),
        ]);
      }
    }

    void handleTerminate(void Function() codeToUpdate) {
      isDone = true;
      codeToUpdate();
      observer.onElse(resultErrors);
    }

    try {
      left._run(
        sharedContRuntime,
        ContObserver._(
          (errors) {
            if (sharedContRuntime.isCancelled()) {
              return;
            }
            handleTerminate(() {
              resultErrors.insertAll(0, errors);
            });
          },
          (a) {
            if (sharedContRuntime.isCancelled()) {
              return;
            }
            // strict order must be followed
            outerA1 = a;
            handleValue();
          },
        ),
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
        ContObserver._(
          (errors) {
            if (sharedContRuntime.isCancelled()) {
              return;
            }
            handleTerminate(() {
              resultErrors.addAll(errors);
            });
          },
          (a2) {
            if (sharedContRuntime.isCancelled()) {
              return;
            }
            // strict order must be followed
            outerA2 = a2;
            handleValue();
          },
        ),
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
