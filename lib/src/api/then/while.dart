part of '../../cont.dart';

extension ContThenWhileExtension<E, F, A> on Cont<E, F, A> {
  /// Repeatedly executes the continuation as long as the predicate returns `true`,
  /// stopping when it returns `false`.
  ///
  /// Runs the continuation in a loop, testing each result with the predicate.
  /// The loop continues as long as the predicate returns `true`, and stops
  /// successfully when the predicate returns `false`.
  ///
  /// The loop is stack-safe and handles asynchronous continuations correctly.
  /// If the continuation terminates or if the predicate throws an exception,
  /// the loop stops and propagates the errors.
  ///
  /// This is useful for retry logic, polling, or repeating an operation while
  /// a condition holds.
  ///
  /// - [predicate]: Function that tests the value. Returns `true` to continue
  ///   looping, or `false` to stop and succeed with the value.
  ///
  /// Example:
  /// ```dart
  /// // Poll an API while data is not ready
  /// final result = fetchData().thenWhile((response) => !response.isReady);
  ///
  /// // Retry while value is below threshold
  /// final value = computation().thenWhile((n) => n < 100);
  /// ```
  Cont<E, F, A> thenWhile(
    bool Function(A value) predicate,
  ) {
    return Cont.fromRun((runtime, observer) {
      _stackSafeLoop<
          _Triple<_KeepGoing, _Cancelled,
              _Either<_Either<ContCrash, F>, A>>,
          _IgnoredPayload,
          _Either<_Cancelled,
              _Either<_Either<ContCrash, F>, A>>>(
        seed: _Value1(()),
        keepRunningIf: (state) {
          switch (state) {
            case _Value1<_KeepGoing, _Cancelled,
                  _Either<_Either<ContCrash, F>, A>>():
              // Keep running - need to execute the continuation again
              return _StackSafeLoopPolicyKeepRunning(());
            case _Value2<_KeepGoing, _Cancelled,
                  _Either<_Either<ContCrash, F>, A>>():
              return _StackSafeLoopPolicyStop(_Left(()));
            case _Value3<_KeepGoing, _Cancelled,
                  _Either<_Either<ContCrash, F>, A>>(
                c: final result
              ):
              return _StackSafeLoopPolicyStop(
                  _Right(result));
          }
        },
        computation: (_, callback) {
          ContCrash.tryCatch(() {
            runWith(
              runtime,
              observer.copyUpdate<F, A>(
                onCrash: (crash) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  callback(_Value3(_Left(_Left(crash))));
                },
                onElse: (error) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  // Terminated - stop the loop with error
                  callback(_Value3(_Left(_Right(error))));
                },
                onThen: (a) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  ContCrash.tryCatch(() {
                    // Check the predicate
                    if (!predicate(a)) {
                      // Predicate satisfied - stop with success
                      callback(_Value3(_Right(a)));
                    } else {
                      // Predicate not satisfied - retry
                      callback(_Value1(()));
                    }
                  }).match((_) {}, (innerCrash) {
                    callback(
                      _Value3(_Left(_Left(innerCrash))),
                    );
                  });
                },
              ),
            );
          }).match((_) {}, (crash) {
            callback(_Value3(_Left(_Left(crash))));
          });
        },
        escape: (result) {
          switch (result) {
            case _Left<(),
                  _Either<_Either<ContCrash, F>, A>>():
              // cancellation
              return;
            case _Right<(),
                  _Either<_Either<ContCrash, F>, A>>(
                value: final crashOrFOrA,
              ):
              switch (crashOrFOrA) {
                case _Left<_Either<ContCrash, F>, A>(
                    value: final crashOrF
                  ):
                  switch (crashOrF) {
                    case _Left<ContCrash, F>(
                        value: final crash
                      ):
                      observer.onCrash(crash);
                    case _Right<ContCrash, F>(
                        value: final f
                      ):
                      observer.onElse(f);
                  }
                case _Right<_Either<ContCrash, F>, A>(
                    value: final a
                  ):
                  observer.onThen(a);
              }
          }
        },
      );
    });
  }

  /// Repeatedly executes based on a zero-argument predicate.
  ///
  /// Similar to [thenWhile] but the predicate doesn't examine the value.
  ///
  /// - [predicate]: Zero-argument function that determines whether to continue looping.
  Cont<E, F, A> thenWhile0(bool Function() predicate) {
    return thenWhile((_) {
      return predicate();
    });
  }

  /// Repeatedly executes with access to both value and environment.
  ///
  /// Similar to [thenWhile], but the predicate function receives both the
  /// current value and the environment. This is useful when loop logic needs
  /// access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and value, and determines whether to continue.
  Cont<E, F, A> thenWhileWithEnv(
    bool Function(E env, A value) predicate,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return thenWhile((a) {
        return predicate(e, a);
      });
    });
  }

  /// Repeatedly executes with access to the environment only.
  ///
  /// Similar to [thenWhileWithEnv], but the predicate only receives the
  /// environment and ignores the current value.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to continue.
  Cont<E, F, A> thenWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return thenWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
