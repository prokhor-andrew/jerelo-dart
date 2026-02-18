part of '../../cont.dart';

extension ContElseTapExtension<E, F, A> on Cont<E, F, A> {
  /// Executes a side-effect continuation on termination.
  ///
  /// If the continuation terminates, executes the side-effect continuation for its effects.
  /// The behavior depends on the side-effect's outcome:
  ///
  /// - If the side-effect terminates: Returns the original errors (ignoring side-effect errors).
  /// - If the side-effect succeeds: Returns the side-effect's success value, effectively
  ///   recovering from the original termination.
  ///
  /// This means the operation can recover from termination if the side-effect succeeds.
  /// If you want to always propagate the original termination regardless of the side-effect's
  /// outcome, use [elseFork] instead.
  ///
  /// - [f]: Function that receives the original errors and returns a side-effect continuation.
  Cont<E, F, A> elseTap(
    Cont<E, F, A> Function(List<ContError<F>> errors) f,
  ) {
    return _elseTap(this, f);
  }

  /// Executes a zero-argument side-effect continuation on termination.
  ///
  /// Similar to [elseTap] but ignores the error information.
  ///
  /// - [f]: Zero-argument function that returns a side-effect continuation.
  Cont<E, F, A> elseTap0(Cont<E, F, A> Function() f) {
    return elseTap((_) {
      return f();
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment.
  ///
  /// Similar to [elseTap], but the side-effect function receives both the errors
  /// and the environment. This allows error-handling side-effects (like logging or
  /// reporting) to access configuration or context information.
  ///
  /// - [f]: Function that takes the environment and errors, and returns a side-effect continuation.
  Cont<E, F, A> elseTapWithEnv(
    Cont<E, F, A> Function(E env, List<ContError<F>> errors)
        f,
  ) {
    return Cont.ask<E, F>().thenDo((e) {
      return elseTap((errors) {
        return f(e, [...errors]);
      });
    });
  }

  /// Executes a side-effect continuation on termination with access to the environment only.
  ///
  /// Similar to [elseTapWithEnv], but the side-effect function only receives
  /// the environment and ignores the error information.
  ///
  /// - [f]: Function that takes the environment and returns a side-effect continuation.
  Cont<E, F, A> elseTapWithEnv0(
      Cont<E, F, A> Function(E env) f) {
    return elseTapWithEnv((e, _) {
      return f(e);
    });
  }
}
