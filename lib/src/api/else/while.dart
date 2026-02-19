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
    bool Function(ContError<F> error) predicate,
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
    bool Function(E env, ContError<F> error) predicate,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
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
