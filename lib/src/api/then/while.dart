part of '../../cont.dart';

extension ContThenWhileExtension<E, A> on Cont<E, A> {
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
  Cont<E, A> thenWhile(bool Function(A value) predicate) {
    return _thenWhile(this, predicate);
  }

  Cont<E, A> thenWhile0(bool Function() predicate) {
    return thenWhile((_) {
      return predicate();
    });
  }

  Cont<E, A> thenWhileWithEnv(
    bool Function(E env, A value) predicate,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenWhile((a) {
        return predicate(e, a);
      });
    });
  }

  Cont<E, A> thenWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return thenWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
