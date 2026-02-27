part of '../../cont.dart';

extension ContElseWhileExtension<E, F, A> on Cont<E, F, A> {
  /// Repeatedly retries the continuation while the predicate returns `true` on termination error.
  ///
  /// If the continuation terminates, tests the error with the predicate. The loop
  /// continues retrying as long as the predicate returns `true`, and stops when the
  /// predicate returns `false` (propagating the termination) or when the continuation
  /// succeeds.
  ///
  /// This is useful for retry logic with error-based conditions, such as retrying
  /// while specific transient error occur.
  ///
  /// - [predicate]: Function that tests the termination error. Returns `true` to retry,
  ///   or `false` to stop and propagate the termination.
  ///
  /// Example:
  /// ```dart
  /// // Retry while getting transient error
  /// final result = apiCall().elseWhile((error) => error.first.error is TransientError);
  /// ```
  Cont<E, F, A> elseWhile(
    bool Function(F error) predicate,
  ) {
    return Cont.fromRun((runtime, observer) {
      _stackSafeLoop<
          _Triple<_KeepGoing, _Cancelled,
              _Either<_Either<ContCrash, A>, F>>,
          _IgnoredPayload,
          _Either<_Cancelled,
              _Either<_Either<ContCrash, A>, F>>>(
        seed: _Value1(()),
        keepRunningIf: (state) {
          switch (state) {
            case _Value1<_KeepGoing, _Cancelled,
                  _Either<_Either<ContCrash, A>, F>>():
              // Keep running - need to execute the continuation again
              return _StackSafeLoopPolicyKeepRunning(());
            case _Value2<_KeepGoing, _Cancelled,
                  _Either<_Either<ContCrash, A>, F>>():
              return _StackSafeLoopPolicyStop(_Left(()));
            case _Value3<_KeepGoing, _Cancelled,
                  _Either<_Either<ContCrash, A>, F>>(
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
                onThen: (a) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  // Terminated - stop the loop with error
                  callback(_Value3(_Left(_Right(a))));
                },
                onElse: (error) {
                  if (runtime.isCancelled()) {
                    callback(_Value2(()));
                    return;
                  }

                  ContCrash.tryCatch(() {
                    // Check the predicate
                    if (!predicate(error)) {
                      // Predicate satisfied - stop with success
                      callback(_Value3(_Right(error)));
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
          }).match((_) {}, (outerCrash) {
            callback(_Value3(_Left(_Left(outerCrash))));
          });
        },
        escape: (result) {
          switch (result) {
            case _Left<(),
                  _Either<_Either<ContCrash, A>, F>>():
              // cancellation
              return;
            case _Right<(),
                  _Either<_Either<ContCrash, A>, F>>(
                value: final crashOrFOrA,
              ):
              switch (crashOrFOrA) {
                case _Left<_Either<ContCrash, A>, F>(
                    value: final crashOrA
                  ):
                  switch (crashOrA) {
                    case _Left<ContCrash, A>(
                        value: final crash
                      ):
                      observer.onCrash(crash);
                    case _Right<ContCrash, A>(
                        value: final a
                      ):
                      observer.onThen(a);
                  }
                case _Right<_Either<ContCrash, A>, F>(
                    value: final f
                  ):
                  observer.onElse(f);
              }
          }
        },
      );
    });
  }

  /// Repeatedly retries while a zero-argument predicate returns `true`.
  ///
  /// Similar to [elseWhile] but the predicate doesn't examine the error.
  ///
  /// - [predicate]: Zero-argument function that determines whether to retry.
  Cont<E, F, A> elseWhile0(bool Function() predicate) {
    return elseWhile((_) {
      return predicate();
    });
  }

  /// Repeatedly retries with access to both error and environment.
  ///
  /// Similar to [elseWhile], but the predicate function receives both the
  /// termination error and the environment. This is useful when retry logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and error, and determines whether to retry.
  Cont<E, F, A> elseWhileWithEnv(
    bool Function(E env, F error) predicate,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return elseWhile((error) {
        return predicate(e, error);
      });
    });
  }

  /// Repeatedly retries with access to the environment only.
  ///
  /// Similar to [elseWhileWithEnv], but the predicate only receives the
  /// environment and ignores the error.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to retry.
  Cont<E, F, A> elseWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return elseWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
