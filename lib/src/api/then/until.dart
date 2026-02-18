part of '../../cont.dart';

extension ContThenUntilExtension<E, F, A> on Cont<E, F, A> {
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
  Cont<E, F, A> thenUntil(
      bool Function(A value) predicate) {
    return thenWhile((a) {
      return !predicate(a);
    });
  }

  /// Repeatedly executes until a zero-argument predicate returns `true`.
  ///
  /// Similar to [thenUntil] but the predicate doesn't examine the value.
  ///
  /// - [predicate]: Zero-argument function that determines when to stop looping.
  Cont<E, F, A> thenUntil0(bool Function() predicate) {
    return thenUntil((_) {
      return predicate();
    });
  }

  /// Repeatedly executes with access to both value and environment.
  ///
  /// Similar to [thenUntil], but the predicate function receives both the
  /// current value and the environment. This is useful when loop logic needs
  /// access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and value, and determines when to stop.
  Cont<E, F, A> thenUntilWithEnv(
    bool Function(E env, A value) predicate,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return thenUntil((a) {
        return predicate(e, a);
      });
    });
  }

  /// Repeatedly executes with access to the environment only.
  ///
  /// Similar to [thenUntilWithEnv], but the predicate only receives the
  /// environment and ignores the current value.
  ///
  /// - [predicate]: Function that takes the environment and determines when to stop.
  Cont<E, F, A> thenUntilWithEnv0(
    bool Function(E env) predicate,
  ) {
    return thenUntilWithEnv((e, _) {
      return predicate(e);
    });
  }
}
