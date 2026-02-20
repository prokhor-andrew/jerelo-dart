part of '../../cont.dart';

/// Implementation of the termination-path retry loop.
///
/// Repeatedly runs [cont] while it terminates and [predicate] returns
/// `true` for the termination error. Stops retrying and propagates the
/// termination when the predicate returns `false`, or succeeds if the
/// continuation eventually succeeds. Uses [_stackSafeLoop] for stack
/// safety across both synchronous and asynchronous iterations.
///
///
///

Cont<E, F, A> _elseWhile<E, F, A>(
  Cont<E, F, A> cont,
  bool Function(F error) predicate,
) {
  return Cont.fromRun((runtime, observer) {
    _stackSafeLoop<
        _Triple<_KeepGoing, _Cancelled,
            _Either<_Either<OnCrash, A>, F>>,
        _IgnoredPayload,
        _Either<_Cancelled,
            _Either<_Either<OnCrash, A>, F>>>(
      seed: _Value1(()),
      keepRunningIf: (state) {
        switch (state) {
          case _Value1<_KeepGoing, _Cancelled,
                _Either<_Either<OnCrash, A>, F>>():
            // Keep running - need to execute the continuation again
            return _StackSafeLoopPolicyKeepRunning(());
          case _Value2<_KeepGoing, _Cancelled,
                _Either<_Either<OnCrash, A>, F>>():
            return _StackSafeLoopPolicyStop(_Left(()));
          case _Value3<_KeepGoing, _Cancelled,
                _Either<_Either<OnCrash, A>, F>>(
              c: final result
            ):
            return _StackSafeLoopPolicyStop(_Right(result));
        }
      },
      computation: (_, callback) {
        final onOuterCrash = observer.safeRun(() {
          cont.runWith(
            runtime,
            observer.copyUpdateOnThen<A>((a) {
              if (runtime.isCancelled()) {
                callback(_Value2(()));
                return;
              }

              // Terminated - stop the loop with error
              callback(_Value3(_Left(_Right(a))));
            }).copyUpdateOnElse<F>((error) {
              if (runtime.isCancelled()) {
                callback(_Value2(()));
                return;
              }

              final onInnerCrash = observer.safeRun(() {
                // Check the predicate
                if (!predicate(error)) {
                  // Predicate satisfied - stop with success
                  callback(_Value3(_Right(error)));
                } else {
                  // Predicate not satisfied - retry
                  callback(_Value1(()));
                }
              });

              if (onInnerCrash != null) {
                callback(
                    _Value3(_Left(_Left(onInnerCrash))));
              }
            }),
          );
        });
        if (onOuterCrash != null) {
          callback(_Value3(_Left(_Left(onOuterCrash))));
        }
      },
      escape: (result) {
        switch (result) {
          case _Left<(), _Either<_Either<OnCrash, A>, F>>():
            // cancellation
            return;
          case _Right<(), _Either<_Either<OnCrash, A>, F>>(
              value: final crashOrFOrA,
            ):
            switch (crashOrFOrA) {
              case _Left<_Either<OnCrash, A>, F>(
                  value: final crashOrA
                ):
                switch (crashOrA) {
                  case _Left<OnCrash, A>(
                      value: final onCrash
                    ):
                    onCrash();
                  case _Right<OnCrash, A>(value: final a):
                    observer.onThen(a);
                }
              case _Right<_Either<OnCrash, A>, F>(
                  value: final f
                ):
                observer.onElse(f);
            }
        }
      },
    );
  });
}

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
    return _elseWhile(this, predicate);
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
