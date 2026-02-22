part of '../../cont.dart';

extension ContCrashWhileExtension<E, F, A>
    on Cont<E, F, A> {
  /// Repeatedly retries the continuation while the predicate returns `true` on crash.
  ///
  /// If the continuation crashes, tests the crash with the predicate. The loop
  /// continues retrying as long as the predicate returns `true`, and stops when the
  /// predicate returns `false` (propagating the crash) or when the continuation
  /// succeeds or terminates.
  ///
  /// This is useful for retry logic with crash-based conditions, such as retrying
  /// while specific transient crashes occur.
  ///
  /// - [predicate]: Function that tests the crash. Returns `true` to retry,
  ///   or `false` to stop and propagate the crash.
  Cont<E, F, A> crashWhile(
    bool Function(ContCrash crash) predicate,
  ) {
    return Cont.fromRun((runtime, observer) {
      _stackSafeLoop<
          _Triple<_KeepGoing, _Cancelled,
              _Either<ContCrash, _Either<F, A>>>,
          _IgnoredPayload,
          _Either<_Cancelled,
              _Either<ContCrash, _Either<F, A>>>>(
        seed: _Value1(()),
        keepRunningIf: (state) {
          switch (state) {
            case _Value1<_KeepGoing, _Cancelled,
                  _Either<ContCrash, _Either<F, A>>>():
              // Keep running - need to execute the continuation again
              return _StackSafeLoopPolicyKeepRunning(());
            case _Value2<_KeepGoing, _Cancelled,
                  _Either<ContCrash, _Either<F, A>>>():
              return _StackSafeLoopPolicyStop(_Left(()));
            case _Value3<_KeepGoing, _Cancelled,
                  _Either<ContCrash, _Either<F, A>>>(
                c: final result
              ):
              return _StackSafeLoopPolicyStop(
                  _Right(result));
          }
        },
        computation: (_, callback) {
          final outerCrash = ContCrash.tryCatch(() {
            runWith(
              runtime,
              observer.copyUpdate<F, A>(
                onThen: (a) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  // Succeeded - stop the loop with value
                  callback(_Value3(_Right(_Right(a))));
                },
                onElse: (error) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  // Terminated - stop the loop with error
                  callback(_Value3(_Right(_Left(error))));
                },
                onCrash: (crash) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  final innerCrash = ContCrash.tryCatch(() {
                    // Check the predicate
                    if (!predicate(crash)) {
                      // Predicate not satisfied - stop with crash
                      callback(_Value3(_Left(crash)));
                    } else {
                      // Predicate satisfied - retry
                      callback(_Value1(()));
                    }
                  });
                  if (innerCrash != null) {
                    callback(
                      _Value3(_Left(innerCrash)),
                    );
                  }
                },
              ),
            );
          });
          if (outerCrash != null) {
            callback(_Value3(_Left(outerCrash)));
          }
        },
        escape: (result) {
          switch (result) {
            case _Left<(),
                  _Either<ContCrash, _Either<F, A>>>():
              // cancellation
              return;
            case _Right<(),
                  _Either<ContCrash, _Either<F, A>>>(
                value: final crashOrResult,
              ):
              switch (crashOrResult) {
                case _Left<ContCrash, _Either<F, A>>(
                    value: final crash
                  ):
                  observer.onCrash(crash);
                case _Right<ContCrash, _Either<F, A>>(
                    value: final fOrA
                  ):
                  switch (fOrA) {
                    case _Left<F, A>(value: final f):
                      observer.onElse(f);
                    case _Right<F, A>(value: final a):
                      observer.onThen(a);
                  }
              }
          }
        },
      );
    });
  }

  /// Repeatedly retries while a zero-argument predicate returns `true`.
  ///
  /// Similar to [crashWhile] but the predicate doesn't examine the crash.
  ///
  /// - [predicate]: Zero-argument function that determines whether to retry.
  Cont<E, F, A> crashWhile0(bool Function() predicate) {
    return crashWhile((_) {
      return predicate();
    });
  }

  /// Repeatedly retries with access to both crash and environment.
  ///
  /// Similar to [crashWhile], but the predicate function receives both the
  /// crash and the environment. This is useful when retry logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and crash, and determines whether to retry.
  Cont<E, F, A> crashWhileWithEnv(
    bool Function(E env, ContCrash crash) predicate,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return crashWhile((crash) {
        return predicate(e, crash);
      });
    });
  }

  /// Repeatedly retries with access to the environment only.
  ///
  /// Similar to [crashWhileWithEnv], but the predicate only receives the
  /// environment and ignores the crash.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to retry.
  Cont<E, F, A> crashWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return crashWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
