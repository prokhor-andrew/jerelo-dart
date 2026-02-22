import 'package:jerelo/jerelo.dart';

extension ContThenIfExtension<E, F, A> on Cont<E, F, A> {
  /// Conditionally succeeds only when the predicate is satisfied.
  ///
  /// Filters the continuation based on the predicate. If the predicate returns
  /// `true`, the continuation succeeds with the value. If the predicate returns
  /// `false`, the continuation terminates with the provided error (or no error
  /// if none are specified).
  ///
  /// This is useful for conditional execution where you want to treat a
  /// predicate failure as termination rather than an error.
  ///
  /// - [predicate]: Function that tests the value.
  /// - [error]: Optional list of error to use when terminating on predicate failure.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.of(42).thenIf((n) => n > 0);
  /// // Succeeds with 42
  ///
  /// final cont2 = Cont.of(-5).thenIf((n) => n > 0);
  /// // Terminates without error
  ///
  /// final cont3 = Cont.of(-5).thenIf(
  ///   (n) => n > 0,
  ///   [ContError.capture('Value must be positive')],
  /// );
  /// // Terminates with custom error
  /// ```
  Cont<E, F, A> thenIf(
    bool Function(A value) predicate, {
    required F fallback,
  }) {
    return thenDo((a) {
      if (predicate(a)) {
        return Cont.of(a);
      }

      return Cont.error<E, F, A>(fallback);
    });
  }

  /// Conditionally succeeds based on a zero-argument predicate.
  ///
  /// Similar to [thenIf] but the predicate doesn't examine the value.
  ///
  /// - [predicate]: Zero-argument function that determines success or termination.
  /// - [error]: Optional list of error to use when terminating on predicate failure.
  Cont<E, F, A> thenIf0(
    bool Function() predicate, {
    required F fallback,
  }) {
    return thenIf((_) {
      return predicate();
    }, fallback: fallback);
  }

  /// Conditionally succeeds with access to both value and environment.
  ///
  /// Similar to [thenIf], but the predicate function receives both the
  /// current value and the environment. This is useful when conditional logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and value, and determines success or termination.
  /// - [error]: Optional list of error to use when terminating on predicate failure.
  Cont<E, F, A> thenIfWithEnv(
    bool Function(E env, A value) predicate, {
    required F fallback,
  }) {
    return Cont.askThen<E, F>().thenDo((e) {
      return thenIf((a) {
        return predicate(e, a);
      }, fallback: fallback);
    });
  }

  /// Conditionally succeeds with access to the environment only.
  ///
  /// Similar to [thenIfWithEnv], but the predicate only receives the
  /// environment and ignores the current value.
  ///
  /// - [predicate]: Function that takes the environment and determines success or termination.
  /// - [error]: Optional list of error to use when terminating on predicate failure.
  Cont<E, F, A> thenIfWithEnv0(
    bool Function(E env) predicate, {
    required F fallback,
  }) {
    return thenIfWithEnv((e, _) {
      return predicate(e);
    }, fallback: fallback);
  }
}
