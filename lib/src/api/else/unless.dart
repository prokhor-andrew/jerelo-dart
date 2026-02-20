import 'package:jerelo/jerelo.dart';

extension ContElseIfExtension<E, F, A> on Cont<E, F, A> {
  /// Conditionally recovers from termination when the predicate is satisfied.
  ///
  /// Filters termination based on the predicate. If the predicate returns
  /// `true`, the continuation recovers with the provided value. If the predicate
  /// returns `false`, the continuation continues terminating with the original error.
  ///
  /// This is the error-channel counterpart to [thenIf]. While [thenIf] filters
  /// values on the success channel, [elseIf] filters error on the termination
  /// channel and provides conditional recovery.
  ///
  /// This is useful for recovering from specific error conditions while letting
  /// other error propagate through.
  ///
  /// - [predicate]: Function that tests the error list.
  /// - [value]: The value to recover with when the predicate returns `true`.
  ///
  /// Example:
  /// ```dart
  /// final cont = Cont.terminate<(), int>([ContError.capture('not found')])
  ///   .elseIf((error) => error.first.error == 'not found', 42);
  /// // Recovers with 42
  ///
  /// final cont2 = Cont.terminate<(), int>([ContError.capture('fatal error')])
  ///   .elseIf((error) => error.first.error == 'not found', 42);
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

  /// Conditionally recovers based on a zero-argument predicate.
  ///
  /// Similar to [elseIf] but the predicate doesn't examine the error.
  ///
  /// - [predicate]: Zero-argument function that determines whether to recover.
  /// - [value]: The value to recover with when the predicate returns `true`.
  Cont<E, F, A> elseUnless0(
    bool Function() predicate, {
    required A fallback,
  }) {
    return elseUnless((_) {
      return predicate();
    }, fallback: fallback);
  }

  /// Conditionally recovers with access to both error and environment.
  ///
  /// Similar to [elseIf], but the predicate function receives both the
  /// termination error and the environment. This is useful when recovery logic
  /// needs access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and error, and determines whether to recover.
  /// - [value]: The value to recover with when the predicate returns `true`.
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

  /// Conditionally recovers with access to the environment only.
  ///
  /// Similar to [elseIfWithEnv], but the predicate only receives the
  /// environment and ignores the error.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to recover.
  /// - [value]: The value to recover with when the predicate returns `true`.
  Cont<E, F, A> elseUnlessWithEnv0(
    bool Function(E env) predicate, {
    required A fallback,
  }) {
    return elseUnlessWithEnv((e, _) {
      return predicate(e);
    }, fallback: fallback);
  }
}
