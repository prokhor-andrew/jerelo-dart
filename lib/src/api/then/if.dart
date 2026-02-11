part of '../../cont.dart';

extension ContThenIfExtension<E, A> on Cont<E, A> {
  /// Conditionally succeeds only when the predicate is satisfied.
  ///
  /// Filters the continuation based on the predicate. If the predicate returns
  /// `true`, the continuation succeeds with the value. If the predicate returns
  /// `false`, the continuation terminates without errors.
  ///
  /// This is useful for conditional execution where you want to treat a
  /// predicate failure as termination rather than an error.
  ///
  /// - [predicate]: Function that tests the value.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.of(42).thenIf((n) => n > 0);
  /// // Succeeds with 42
  ///
  /// final cont2 = Cont.of(-5).thenIf((n) => n > 0);
  /// // Terminates
  /// ```
  Cont<E, A> thenIf(bool Function(A value) predicate) {
    return thenDo((a) {
      if (predicate(a)) {
        return Cont.of(a);
      }

      return Cont.terminate<E, A>();
    });
  }

  /// Conditionally succeeds based on a zero-argument predicate.
  ///
  /// Similar to [thenIf] but the predicate doesn't examine the value.
  ///
  /// - [predicate]: Zero-argument function that determines success or termination.
  Cont<E, A> thenIf0(bool Function() predicate) {
    return thenIf((_) {
      return predicate();
    });
  }

  /// Conditionally succeeds with access to both value and environment.
  ///
  /// Similar to [thenIf], but the predicate function receives both the
  /// current value and the environment. This is useful when conditional logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and value, and determines success or termination.
  Cont<E, A> thenIfWithEnv(
    bool Function(E env, A value) predicate,
  ) {
    return Cont.ask<E>().thenDo((e) {
      return thenIf((a) {
        return predicate(e, a);
      });
    });
  }

  /// Conditionally succeeds with access to the environment only.
  ///
  /// Similar to [thenIfWithEnv], but the predicate only receives the
  /// environment and ignores the current value.
  ///
  /// - [predicate]: Function that takes the environment and determines success or termination.
  Cont<E, A> thenIfWithEnv0(
    bool Function(E env) predicate,
  ) {
    return thenIfWithEnv((e, _) {
      return predicate(e);
    });
  }
}
