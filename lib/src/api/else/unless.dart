import 'package:jerelo/jerelo.dart';

extension ContElseIfExtension<E, F, A> on Cont<E, F, A> {
  /// Conditionally promotes from error to success when the predicate is not satisfied.
  ///
  /// Filters termination based on the predicate. If the predicate returns
  /// `true`, the continuation continues terminating with the original error.
  /// If the predicate returns `false`, the continuation promotes to success
  /// with the provided [fallback] value.
  ///
  /// This is the error-channel counterpart to [thenIf]. While [thenIf] filters
  /// values on the success channel, [elseUnless] filters errors on the else
  /// channel and provides conditional promotion.
  ///
  /// This is useful for promoting past specific error conditions while letting
  /// other errors propagate through.
  ///
  /// - [predicate]: Function that tests the error value. Returns `true` to keep
  ///   the error, or `false` to promote with [fallback].
  /// - [fallback]: The value to promote with when the predicate returns `false`.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.error<(), String, int>('not found')
  ///   .elseUnless((error) => error == 'not found', fallback: 42);
  /// // Recovers with 42
  ///
  /// final cont2 = Cont.error<(), String, int>('fatal error')
  ///   .elseUnless((error) => error == 'not found', fallback: 42);
  /// // Continues terminating with 'fatal error'
  /// ```
  Cont<E, F, A> elseUnless(
    bool Function(F error) predicate, {
    required A fallback,
  }) {
    return elseDo((error) {
      if (predicate(error)) {
        return Cont.error(error);
      }

      return Cont.of(fallback);
    });
  }

  /// Conditionally promotes based on a zero-argument predicate.
  ///
  /// Similar to [elseUnless] but the predicate doesn't examine the error.
  ///
  /// - [predicate]: Zero-argument function that determines whether to keep the error.
  /// - [fallback]: The value to promote with when the predicate returns `false`.
  Cont<E, F, A> elseUnless0(
    bool Function() predicate, {
    required A fallback,
  }) {
    return elseUnless((_) {
      return predicate();
    }, fallback: fallback);
  }

  /// Conditionally promotes with access to both error and environment.
  ///
  /// Similar to [elseUnless], but the predicate function receives both the
  /// termination error and the environment. This is useful when promotion logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and error, and determines whether to keep the error.
  /// - [fallback]: The value to promote with when the predicate returns `false`.
  Cont<E, F, A> elseUnlessWithEnv(
    bool Function(E env, F error) predicate, {
    required A fallback,
  }) {
    return Cont.askThen<E, F>().thenDo((e) {
      return elseUnless((error) {
        return predicate(e, error);
      }, fallback: fallback);
    });
  }

  /// Conditionally promotes with access to the environment only.
  ///
  /// Similar to [elseUnlessWithEnv], but the predicate only receives the
  /// environment and ignores the error.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to keep the error.
  /// - [fallback]: The value to promote with when the predicate returns `false`.
  Cont<E, F, A> elseUnlessWithEnv0(
    bool Function(E env) predicate, {
    required A fallback,
  }) {
    return elseUnlessWithEnv((e, _) {
      return predicate(e);
    }, fallback: fallback);
  }
}
