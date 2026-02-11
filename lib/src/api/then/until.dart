part of '../../cont.dart';

extension ContThenUntilExtension<E, A> on Cont<E, A> {
  /// Repeatedly executes the continuation until the predicate returns `true`.
  ///
  /// Runs the continuation in a loop, testing each result with the predicate.
  /// The loop continues while the predicate returns `false`, and stops
  /// successfully when the predicate returns `true`.
  ///
  /// This is the inverse of [thenWhile] - implemented as `asLongAs((a) => !predicate(a))`.
  /// Use this when you want to retry until a condition is met.
  ///
  /// - [predicate]: Function that tests the value. Returns `true` to stop the loop
  ///   and succeed, or `false` to continue looping.
  ///
  /// Example:
  /// ```dart
  /// // Retry until a condition is met
  /// final result = fetchStatus().thenUntil((status) => status == 'complete');
  ///
  /// // Poll until a threshold is reached
  /// final value = checkProgress().thenUntil((progress) => progress >= 100);
  /// ```
  Cont<E, A> thenUntil(bool Function(A value) predicate) {
    return thenWhile((a) {
      return !predicate(a);
    });
  }

  Cont<E, A> thenUntil0(bool Function() predicate) {
    return thenUntil((_) {
      return predicate();
    });
  }

  Cont<E, A> thenUntilWithEnv(
    bool Function(E env, A value) predicate,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenUntil((a) {
        return predicate(e, a);
      });
    });
  }

  Cont<E, A> thenUntilWithEnv0(
    bool Function(E env) predicate,
  ) {
    return thenUntilWithEnv((e, _) {
      return predicate(e);
    });
  }
}
