part of '../../cont.dart';

extension ContElseWhileExtension<E, A> on Cont<E, A> {
  /// Repeatedly retries the continuation while the predicate returns `true` on termination errors.
  ///
  /// If the continuation terminates, tests the errors with the predicate. The loop
  /// continues retrying as long as the predicate returns `true`, and stops when the
  /// predicate returns `false` (propagating the termination) or when the continuation
  /// succeeds.
  ///
  /// This is useful for retry logic with error-based conditions, such as retrying
  /// while specific transient errors occur.
  ///
  /// - [predicate]: Function that tests the termination errors. Returns `true` to retry,
  ///   or `false` to stop and propagate the termination.
  ///
  /// Example:
  /// ```dart
  /// // Retry while getting transient errors
  /// final result = apiCall().elseWhile((errors) => errors.first.error is TransientError);
  /// ```
  Cont<E, A> elseWhile(
    bool Function(List<ContError> errors) predicate,
  ) {
    return _elseWhile(this, predicate);
  }

  /// Repeatedly retries while a zero-argument predicate returns `true`.
  ///
  /// Similar to [elseWhile] but the predicate doesn't examine the errors.
  ///
  /// - [predicate]: Zero-argument function that determines whether to retry.
  Cont<E, A> elseWhile0(bool Function() predicate) {
    return elseWhile((_) {
      return predicate();
    });
  }

  /// Repeatedly retries with access to both errors and environment.
  ///
  /// Similar to [elseWhile], but the predicate function receives both the
  /// termination errors and the environment. This is useful when retry logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and errors, and determines whether to retry.
  Cont<E, A> elseWhileWithEnv(
    bool Function(E env, List<ContError> errors) predicate,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return elseWhile((errors) {
        return predicate(e, errors);
      });
    });
  }

  /// Repeatedly retries with access to the environment only.
  ///
  /// Similar to [elseWhileWithEnv], but the predicate only receives the
  /// environment and ignores the errors.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to retry.
  Cont<E, A> elseWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return elseWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
