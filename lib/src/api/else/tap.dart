part of '../../cont.dart';

extension ContElseTapExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on termination.
  ///
  /// If the continuation terminates, executes the side-effect continuation for its effects.
  /// The behavior depends on the side-effect's outcome:
  ///
  /// - If the side-effect terminates: Returns the original error (ignoring side-effect error).
  /// - If the side-effect succeeds: Returns the side-effect's success value, effectively
  ///   recovering from the original termination.
  ///
  /// This means the operation can recover from termination if the side-effect succeeds.
  /// If you want to always propagate the original termination regardless of the side-effect's
  /// outcome, use [elseFork] instead.
  ///
  /// - [f]: Function that receives the original error and returns a side-effect continuation.
  Cont<E, F, A> elseTap<F2>(
    Cont<E, F2, A> Function(ContError<F> error) f,
  ) {
    return _elseTap(this, f);
  }

  /// Executes a zero-argument side-effect continuation on termination.
  ///
  /// Similar to [elseTap] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> elseTap0<F2>(Cont<E, F2, A> Function() f) {
    return elseTap((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment.
  ///
  /// Similar to [elseTap], but the side-effect function receives both the error
  /// and the environment. This allows error-handling side-effects (like logging or
  /// reporting) to access configuration or context information.
  ///
  /// - [f]: Function that takes the environment and error, and returns a side-effect continuation.
  Cont<E, F, A> elseTapWithEnv<F2>(
    Cont<E, F2, A> Function(E env, ContError<F> error) f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return elseTap((error) {
        return f(e, error);
      });
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment only.
  ///
  /// Similar to [elseTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> elseTapWithEnv0<F2>(
      Cont<E, F2, A> Function(E env) f) {
    return elseTapWithEnv((e, _) {
      return f(e);
    });
  }
}
