import 'package:jerelo/jerelo.dart';

extension ContThenWhileExtension<E, F, A> on Cont<E, F, A> {
  /// Repeatedly executes the continuation as long as the predicate returns `true`,
  /// stopping when it returns `false`.
  ///
  /// Runs the continuation in a loop, testing each result with the predicate.
  /// The loop continues as long as the predicate returns `true`, and stops
  /// successfully when the predicate returns `false`.
  ///
  /// The continuation always runs at least once. The loop is built on
  /// [Cont.tailRecM], so it is stack-safe and handles asynchronous
  /// continuations correctly. If the continuation terminates on the else
  /// channel or crashes, the loop stops and propagates that outcome; if the
  /// predicate throws, the computation crashes.
  ///
  /// This is useful for polling, or repeating an operation while a condition
  /// holds.
  ///
  /// - [predicate]: Function that tests the value. Returns `true` to continue
  ///   looping, or `false` to stop and succeed with the value.
  ///
  /// Example:
  /// ```dart
  /// // Poll an API while data is not ready
  /// final result = fetchData().thenWhile((response) => !response.isReady);
  ///
  /// // Repeat while value is below threshold
  /// final value = computation().thenWhile((n) => n < 100);
  /// ```
  Cont<E, F, A> thenWhile(
    bool Function(A value) predicate,
  ) {
    return Cont.tailRecM<E, F, (), A>((), (_) {
      return thenMap((value) {
        return predicate(value)
            ? TailRec.next(())
            : TailRec.done(value);
      });
    });
  }

  /// Repeatedly executes based on a zero-argument predicate.
  ///
  /// Similar to [thenWhile] but the predicate doesn't examine the value.
  ///
  /// - [predicate]: Zero-argument function that determines whether to continue looping.
  Cont<E, F, A> thenWhile0(bool Function() predicate) {
    return thenWhile((_) {
      return predicate();
    });
  }

  /// Repeatedly executes with access to both value and environment.
  ///
  /// Similar to [thenWhile], but the predicate function receives both the
  /// current value and the environment. This is useful when loop logic needs
  /// access to configuration or context information.
  ///
  /// - [predicate]: Function that takes the environment and value, and determines whether to continue.
  Cont<E, F, A> thenWhileWithEnv(
    bool Function(E env, A value) predicate,
  ) {
    return Cont.askThen<E, F>().thenDo((e) {
      return thenWhile((a) {
        return predicate(e, a);
      });
    });
  }

  /// Repeatedly executes with access to the environment only.
  ///
  /// Similar to [thenWhileWithEnv], but the predicate only receives the
  /// environment and ignores the current value.
  ///
  /// - [predicate]: Function that takes the environment and determines whether to continue.
  Cont<E, F, A> thenWhileWithEnv0(
    bool Function(E env) predicate,
  ) {
    return thenWhileWithEnv((e, _) {
      return predicate(e);
    });
  }
}
