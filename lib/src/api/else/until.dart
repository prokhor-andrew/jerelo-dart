part of '../../cont.dart';

extension ContElseUntilExtension<E, F, A> on Cont<E, F, A> {
  /// Repeatedly retries the continuation until the predicate returns `true` on termination error.
  ///
  /// If the continuation terminates, tests the error with the predicate. The loop
  /// continues retrying while the predicate returns `false`, and stops when the
  /// predicate returns `true` (propagating the termination) or when the continuation
  /// succeeds.
  ///
  /// This is the inverse of [elseWhile] - implemented as `elseWhile((error) => !predicate(error))`.
  /// Use this when you want to retry until a specific error condition is met.
  ///
  /// - [predicate]: Function that tests the termination error. Returns `true` to stop
  ///   and propagate the termination, or `false` to continue retrying.
  ///
  /// Example:
  /// ```dart
  /// // Retry until a fatal error occurs
  /// final result = apiCall().elseUntil((error) => error.first.error is FatalError);
  /// ```
  Cont<E, F, A> elseUntil(
    bool Function(ContError<F> error) predicate,
  ) {
    return elseWhile((error) {
      return !predicate(error);
    });
  }

  /// Repeatedly retries until a zero-argument predicate returns `true`.
  ///
  /// Similar to [elseUntil] but the predicate doesn't examine the error.
  ///
  /// - [predicate]: Zero-argument function that determines when to stop retrying.
  Cont<E, F, A> elseUntil0(bool Function() predicate) {
    return elseUntil((_) {
      return predicate();
    });
  }

  /// Repeatedly retries with access to both error and environment.
  ///
  /// Similar to [elseUntil], but the predicate function receives both the
  /// termination error and the environment. This is useful when retry logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and error, and determines when to stop.
  Cont<E, F, A> elseUntilWithEnv(
    bool Function(E env, ContError<F> error) predicate,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return elseUntil((error) {
        return predicate(e, error);
      });
    });
  }

  /// Repeatedly retries with access to the environment only.
  ///
  /// Similar to [elseUntilWithEnv], but the predicate only receives the
  /// environment and ignores the error.
  ///
  /// - [predicate]: Function that takes the environment and determines when to stop.
  Cont<E, F, A> elseUntilWithEnv0(
    bool Function(E env) predicate,
  ) {
    return elseUntilWithEnv((e, _) {
      return predicate(e);
    });
  }
}
